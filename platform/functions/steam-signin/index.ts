// The steam-signin platform function: POST /functions/v1/steam-signin
//   {"ticket": "<hex from GetAuthTicketForWebApi(STEAM_IDENTITY)>"}
// with the player's own Authorization header to link Steam to them, or
// none to sign in with Steam. What it does is steam.ts; this wires it to
// Steam's Web API and the platform's sign-in, data API and service key.
//
// Needs, in the functions container's environment (supabase/platform.yml):
//   STEAM_WEB_API_KEY   a publisher Web API key (secret)
//   STEAM_APP_ID        the game's app id
//   STEAM_IDENTITY      the identity the game passes GetAuthTicketForWebApi
// and Supabase's own SUPABASE_URL, SUPABASE_SERVICE_ROLE_KEY, SUPABASE_ANON_KEY.

import { steamSignIn, type Deps, type Session } from './steam.ts'

const env = (name: string): string => Deno.env.get(name) ?? ''
const PLATFORM = env('SUPABASE_URL')
const SERVICE = env('SUPABASE_SERVICE_ROLE_KEY')

async function platform(path: string, init: RequestInit & { token?: string } = {}): Promise<Response> {
  const headers = new Headers(init.headers)
  headers.set('apikey', init.token ? env('SUPABASE_ANON_KEY') : SERVICE)
  headers.set('Authorization', `Bearer ${init.token ?? SERVICE}`)
  headers.set('Content-Type', 'application/json')
  return await fetch(PLATFORM + path, { ...init, headers })
}

async function json(response: Response, what: string): Promise<any> {
  const body = await response.json().catch(() => null)
  if (!response.ok) throw new Error(`${what}: ${response.status} ${JSON.stringify(body)}`)
  return body
}

const deps: Deps = {
  async verifyTicket(ticket) {
    const query = new URLSearchParams({ key: env('STEAM_WEB_API_KEY'), appid: env('STEAM_APP_ID'), ticket, identity: env('STEAM_IDENTITY') })
    // a failed fetch names its URL, and the URL carries the key: never let that reach the log
    const response = await fetch(`https://partner.steam-api.com/ISteamUserAuth/AuthenticateUserTicket/v1/?${query}`).catch(() => {
      throw new Error('Steam did not answer')
    })
    const body = await response.json().catch(() => null)
    const params = body?.response?.params
    if (params?.result === 'OK' && typeof params.steamid === 'string') {
      if (params.publisherbanned) return { refused: 'this Steam account is banned from the game' }
      return { steamId: params.steamid }
    }
    return { refused: body?.response?.error?.errordesc ?? `Steam answered ${response.status}` }
  },
  async playerOf(token) {
    const response = await platform('/auth/v1/user', { token })
    if (!response.ok) return null
    const user = await response.json()
    return { id: user.id, email: user.email || null }
  },
  async findLink(steamId) {
    return await json(await platform('/rest/v1/rpc/platform_steam_player', { method: 'POST', body: JSON.stringify({ steam_id: steamId }) }), 'finding the Steam link')
  },
  async addLink(steamId, playerId) {
    return await json(await platform('/rest/v1/rpc/platform_link_steam', { method: 'POST', body: JSON.stringify({ steam_id: steamId, player: playerId }) }), 'linking Steam')
  },
  async createPlayer(email) {
    const made = await json(await platform('/auth/v1/admin/users', { method: 'POST', body: JSON.stringify({ email, email_confirm: true }) }), 'creating the player')
    return made.id
  },
  async playerEmail(playerId) {
    const user = await json(await platform(`/auth/v1/admin/users/${playerId}`), 'reading the player')
    return user.email || null
  },
  async setEmail(playerId, email) {
    await json(await platform(`/auth/v1/admin/users/${playerId}`, { method: 'PUT', body: JSON.stringify({ email, email_confirm: true }) }), 'setting the address')
  },
  async sessionFor(email) {
    const link = await json(await platform('/auth/v1/admin/generate_link', { method: 'POST', body: JSON.stringify({ type: 'magiclink', email }) }), 'making the sign-in link')
    const hashed = link.hashed_token ?? link.properties?.hashed_token
    const session = await json(await platform('/auth/v1/verify', { method: 'POST', body: JSON.stringify({ type: 'magiclink', token_hash: hashed }) }), 'redeeming the sign-in link')
    return session as Session
  },
}

Deno.serve(async (request: Request) => {
  if (request.method !== 'POST') return Response.json({ msg: 'POST a ticket' }, { status: 405 })
  // 404, not 503: the platform is well, this function just isn't available here yet
  if (!env('STEAM_WEB_API_KEY') || !env('STEAM_APP_ID')) return Response.json({ msg: 'Steam sign-in is not set up on this platform yet' }, { status: 404 })
  const bearer = request.headers.get('authorization')?.match(/^Bearer\s+(\S+)$/i)?.[1] ?? null
  // a client not signed in sends its publishable key as the bearer, or nothing: neither is a player
  const token = bearer && bearer.split('.').length === 3 && bearer !== env('SUPABASE_ANON_KEY') ? bearer : null
  const body = await request.json().catch(() => null)
  try {
    const answer = await steamSignIn(body, token, deps)
    return Response.json(answer.body, { status: answer.status })
  } catch (error) {
    console.error('steam-signin', error)
    return Response.json({ msg: 'Steam sign-in failed on the server; try again' }, { status: 502 })
  }
})
