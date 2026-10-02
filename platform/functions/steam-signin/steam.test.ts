// steamSignIn against a pretend Steam and a pretend platform:
//   node --test platform/functions/steam-signin/
import { test } from 'node:test'
import assert from 'node:assert/strict'
import { steamSignIn, placeholderEmail, type Deps } from './steam.ts'

const TICKET = '14000000aabbccdd0011223344556677'

// A pretend Steam and platform: tickets map to Steam accounts, tokens to players.
function world() {
  const links = new Map<string, string>()
  const players = new Map<string, { email: string | null }>()
  const tokens = new Map<string, string>()
  const steam = new Map<string, string>([[TICKET, '76561198000000001']])
  let made = 0
  const sessions: string[] = []
  const deps: Deps = {
    async verifyTicket(ticket) {
      const steamId = steam.get(ticket)
      return steamId ? { steamId } : { refused: 'Invalid ticket' }
    },
    async playerOf(token) {
      const id = tokens.get(token)
      return id ? { id, email: players.get(id)!.email } : null
    },
    async findLink(steamId) { return links.get(steamId) ?? null },
    async addLink(steamId, playerId) {
      if (links.has(steamId)) return false
      links.set(steamId, playerId)
      return true
    },
    async createPlayer(email) {
      if ([...players.values()].some((p) => p.email === email)) throw new Error('A user with this email address has already been registered')
      const id = `player-${++made}`
      players.set(id, { email })
      return id
    },
    async playerEmail(id) { return players.get(id)?.email ?? null },
    async setEmail(id, email) { players.get(id)!.email = email },
    async sessionFor(email) {
      sessions.push(email)
      const id = [...players].find(([, p]) => p.email === email)![0]
      return { access_token: `access-${id}`, refresh_token: `refresh-${id}`, user: { id } }
    },
  }
  return { deps, links, players, tokens, steam, sessions }
}

test('a new Steam account becomes a new player, signed in', async () => {
  const w = world()
  const answer = await steamSignIn({ ticket: TICKET }, null, w.deps)
  assert.equal(answer.status, 200)
  assert.equal(answer.body.access_token, 'access-player-1')
  assert.equal(answer.body.steam_id, '76561198000000001')
  assert.equal(w.links.get('76561198000000001'), 'player-1')
  assert.equal(w.players.get('player-1')!.email, placeholderEmail('76561198000000001'))
})

test('the same Steam account signs in as the same player again', async () => {
  const w = world()
  await steamSignIn({ ticket: TICKET }, null, w.deps)
  const again = await steamSignIn({ ticket: TICKET }, null, w.deps)
  assert.equal(again.body.access_token, 'access-player-1')
  assert.equal(w.players.size, 1)
})

test('a signed-in player links their Steam account, and Steam then signs in as them', async () => {
  const w = world()
  w.players.set('google-player', { email: 'ian@example.com' })
  w.tokens.set('tok', 'google-player')
  const linked = await steamSignIn({ ticket: TICKET }, 'tok', w.deps)
  assert.deepEqual(linked, { status: 200, body: { linked: true, steam_id: '76561198000000001' } })
  const later = await steamSignIn({ ticket: TICKET }, null, w.deps)
  assert.equal(later.body.access_token, 'access-google-player')
  assert.deepEqual(w.sessions, ['ian@example.com'], 'their own address is kept')
})

test('an anonymous player who links Steam gets a placeholder address, so Steam alone signs them in', async () => {
  const w = world()
  w.players.set('anon', { email: null })
  w.tokens.set('tok', 'anon')
  await steamSignIn({ ticket: TICKET }, 'tok', w.deps)
  assert.equal(w.players.get('anon')!.email, placeholderEmail('76561198000000001'))
  const later = await steamSignIn({ ticket: TICKET }, null, w.deps)
  assert.equal(later.body.access_token, 'access-anon')
})

test("a Steam account that is another player's can't be linked", async () => {
  const w = world()
  await steamSignIn({ ticket: TICKET }, null, w.deps)
  w.players.set('someone-else', { email: 'x@example.com' })
  w.tokens.set('tok', 'someone-else')
  const refused = await steamSignIn({ ticket: TICKET }, 'tok', w.deps)
  assert.equal(refused.status, 409)
  assert.equal(w.links.get('76561198000000001'), 'player-1')
})

test('linking twice is fine', async () => {
  const w = world()
  w.players.set('p', { email: 'p@example.com' })
  w.tokens.set('tok', 'p')
  await steamSignIn({ ticket: TICKET }, 'tok', w.deps)
  const again = await steamSignIn({ ticket: TICKET }, 'tok', w.deps)
  assert.equal(again.status, 200)
})

test('a ticket Steam refuses signs nobody in', async () => {
  const w = world()
  const answer = await steamSignIn({ ticket: 'deadbeefdeadbeefdeadbeef' }, null, w.deps)
  assert.equal(answer.status, 401)
  assert.match(String(answer.body.msg), /Steam refused/)
  assert.equal(w.players.size, 0)
})

test('a missing or malformed ticket is refused before asking Steam', async () => {
  const w = world()
  let asked = false
  w.deps.verifyTicket = async () => { asked = true; return { refused: 'no' } }
  for (const body of [null, {}, { ticket: 7 }, { ticket: 'not hex!' }, { ticket: 'abc' }]) {
    assert.equal((await steamSignIn(body, null, w.deps)).status, 400)
  }
  assert.equal(asked, false)
})

test('an invalid sign-in token is refused, not treated as signed out', async () => {
  const w = world()
  const answer = await steamSignIn({ ticket: TICKET }, 'stale', w.deps)
  assert.equal(answer.status, 401)
  assert.equal(w.players.size, 0)
})

test('two first sign-ins at once end up as one player', async () => {
  const w = world()
  // the other request makes its player and link just before ours
  const create = w.deps.createPlayer
  w.deps.createPlayer = async (email, steamId) => {
    w.players.set('winner', { email: placeholderEmail(steamId) })
    w.links.set(steamId, 'winner')
    return create(email, steamId)
  }
  const answer = await steamSignIn({ ticket: TICKET }, null, w.deps)
  assert.equal(answer.status, 200)
  assert.equal((answer.body.user as { id: string }).id, 'winner')
  assert.equal(w.players.size, 1, 'and no second player was made')
})
