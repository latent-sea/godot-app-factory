// Steam sign-in: a Steam account is one Latensea player.
//
// The game asks Steam for a web API ticket (Steamworks'
// GetAuthTicketForWebApi, with the identity STEAM_IDENTITY) and sends it
// here. Steam says whose ticket it is; this answers that player's session,
// creating the player the first time, or links the Steam account to the
// player who is already signed in.
//
// - Signed out, Steam account seen before: a session for its player.
// - Signed out, Steam account new: a new player, then a session.
// - Signed in, Steam account new: linked to the signed-in player.
// - Signed in, Steam account already that player's: nothing to do.
// - Signed in, Steam account another player's: refused.
//
// The platform's sign-in (GoTrue) can't hand out a session for a player
// chosen by a server, so the session comes from a one-time sign-in link
// made with the service key and redeemed at once; nothing is emailed. A
// player with no email of their own is given a placeholder address that
// can never receive mail.
//
// This file is plain TypeScript, so Deno runs it on the platform and Node
// runs its tests (steam.test.ts). Everything it reaches is passed in.

export type Session = { access_token: string; refresh_token: string; user: { id: string } }

export type Deps = {
  // Steam's verdict on a ticket: its account, or why it was refused.
  verifyTicket(ticket: string): Promise<{ steamId: string } | { refused: string }>
  // The player a token belongs to, or null if it isn't a valid token.
  playerOf(token: string): Promise<{ id: string; email: string | null } | null>
  // The player a Steam account belongs to, or null.
  findLink(steamId: string): Promise<string | null>
  // Records the Steam account as the player's; false if it already belongs to someone.
  addLink(steamId: string, playerId: string): Promise<boolean>
  // A new player with this address, confirmed; their id. Which Steam account
  // is theirs is recorded by addLink alone (platform.steam_accounts).
  createPlayer(email: string): Promise<string>
  playerEmail(playerId: string): Promise<string | null>
  setEmail(playerId: string, email: string): Promise<void>
  // A session for the player with this address.
  sessionFor(email: string): Promise<Session>
}

export type Answer = { status: number; body: Record<string, unknown> }

// An address that can never receive mail (RFC 2606 reserves .invalid).
export function placeholderEmail(steamId: string): string {
  return `steam-${steamId}@players.latensea.invalid`
}

const TICKET = /^[0-9a-fA-F]{16,4096}$/

export async function steamSignIn(body: unknown, token: string | null, deps: Deps): Promise<Answer> {
  const ticket = (body as { ticket?: unknown } | null)?.ticket
  if (typeof ticket !== 'string' || !TICKET.test(ticket)) {
    return refuse(400, 'Send {"ticket": "<the hex ticket from GetAuthTicketForWebApi>"}')
  }

  let player: { id: string; email: string | null } | null = null
  if (token) {
    player = await deps.playerOf(token)
    if (!player) return refuse(401, 'That sign-in has expired or is invalid; sign in again')
  }

  const verdict = await deps.verifyTicket(ticket)
  if ('refused' in verdict) return refuse(401, `Steam refused the ticket: ${verdict.refused}`)
  const steamId = verdict.steamId

  const owner = await deps.findLink(steamId)

  if (player) {
    if (owner === player.id) return { status: 200, body: { linked: true, steam_id: steamId } }
    if (owner) return refuse(409, 'This Steam account belongs to another player')
    if (!(await deps.addLink(steamId, player.id))) return refuse(409, 'This Steam account belongs to another player')
    // so the player can sign in with Steam alone on another device
    if (!player.email) await deps.setEmail(player.id, placeholderEmail(steamId))
    return { status: 200, body: { linked: true, steam_id: steamId } }
  }

  let playerId = owner
  if (!playerId) {
    // Two first sign-ins at once: the platform refuses the second player (the
    // address is taken), or the second link; either way the first one's player wins.
    const made = await deps.createPlayer(placeholderEmail(steamId)).catch(() => null)
    if (made && (await deps.addLink(steamId, made))) {
      playerId = made
    } else {
      playerId = await deps.findLink(steamId)
      if (!playerId) return refuse(503, 'Signing in with Steam is busy; try again')
    }
  }
  let email = await deps.playerEmail(playerId)
  if (!email) {
    email = placeholderEmail(steamId)
    await deps.setEmail(playerId, email)
  }
  const session = await deps.sessionFor(email)
  return { status: 200, body: { ...session, steam_id: steamId } }
}

function refuse(status: number, msg: string): Answer {
  return { status, body: { msg } }
}
