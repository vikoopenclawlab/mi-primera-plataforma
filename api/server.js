// Fastify API Server
// Environment-agnostic, connects to shared PostgreSQL + Redis + Meilisearch

const DATABASE_URL = process.env.DATABASE_URL || 'postgresql://mi_primera_plataforma:M1p_2026_plat@postgres.viko-apps.svc:5432/mi_primera_plataforma'
const REDIS_URL = process.env.REDIS_URL || 'redis://:@redis.viko-apps.svc:6379/1'
const MEILISEARCH_HOST = process.env.MEILISEARCH_HOST || 'http://meilisearch.plataformas-web.svc:7700'
const MEILISEARCH_API_KEY = process.env.MEILISEARCH_API_KEY || ''
const PORT = parseInt(process.env.PORT || '4000')

// Inline implementations (no external deps needed for basic health)
async function queryDB() {
  const url = new URL(DATABASE_URL)
  const client = await import('pg').then(m => new m.Pool({
    host: url.hostname,
    port: parseInt(url.port || '5432'),
    user: url.username,
    password: url.password,
    database: url.pathname.slice(1),
    max: 1,
    idleTimeoutMillis: 5000,
    connectionTimeoutMillis: 5000,
  }))
  try {
    const result = await client.query('SELECT now() as now, current_database() as db')
    await client.end()
    return { ok: true, db: result.rows[0].db, time: result.rows[0].now }
  } catch (err) {
    await client.end()
    throw err
  }
}

async function queryRedis() {
  const url = new URL(REDIS_URL)
  const net = await import('net')
  return new Promise((resolve, reject) => {
    const socket = net.connect(parseInt(url.port || '6379'), url.hostname, () => {
      const cmd = url.password ? `AUTH ${url.password}\r\nPING\r\n` : `PING\r\n`
      socket.write(cmd)
      let data = ''
      socket.on('data', chunk => { data += chunk.toString() })
      socket.on('end', () => {
        socket.destroy()
        resolve({ ok: true, response: data.trim() })
      })
      socket.on('error', reject)
    })
    socket.on('error', reject)
    socket.setTimeout(5000, () => { socket.destroy(); reject(new Error('timeout')) })
  })
}

async function queryMeilisearch() {
  const url = `${MEILISEARCH_HOST}/health`
  const res = await fetch(url, {
    headers: MEILISEARCH_API_KEY ? { 'Authorization': `Bearer ${MEILISEARCH_API_KEY}` } : {},
    signal: AbortSignal.timeout(5000),
  })
  if (!res.ok) throw new Error(`Meilisearch unhealthy: ${res.status}`)
  const json = await res.json()
  return { ok: true, status: json.status }
}

// Simple HTTP server (pure Node, no framework)
function handler(req, res) {
  const url = new URL(req.url, `http://localhost:${PORT}`)
  const path = url.pathname.replace(/\/$/, '') || '/health'

  // CORS headers
  res.setHeader('Access-Control-Allow-Origin', '*')
  res.setHeader('Access-Control-Allow-Methods', 'GET, OPTIONS')
  res.setHeader('Access-Control-Allow-Headers', 'Content-Type')

  if (req.method === 'OPTIONS') {
    res.writeHead(204)
    res.end()
    return
  }

  const send = (status, data) => {
    res.writeHead(status, { 'Content-Type': 'application/json' })
    res.end(JSON.stringify(data, null, 2))
  }

  const routes = {
    '/health': async () => send(200, { status: 'ok', timestamp: new Date().toISOString(), service: 'fastify-api' }),
    '/api/health': async () => send(200, { status: 'ok', timestamp: new Date().toISOString(), service: 'fastify-api' }),
    '/api/db-test': async () => {
      try {
        const db = await queryDB()
        send(200, { service: 'postgresql', ...db })
      } catch (e) {
        send(503, { service: 'postgresql', error: e.message })
      }
    },
    '/api/redis-test': async () => {
      try {
        const redis = await queryRedis()
        send(200, { service: 'redis', ...redis })
      } catch (e) {
        send(503, { service: 'redis', error: e.message })
      }
    },
    '/api/search-test': async () => {
      try {
        const meili = await queryMeilisearch()
        send(200, meili)
      } catch (e) {
        send(503, { service: 'meilisearch', error: e.message })
      }
    },
    '/api/status': async () => {
      const results = await Promise.allSettled([
        queryDB(),
        queryRedis(),
        queryMeilisearch()
      ])
      const db = results[0]
      const redis = results[1]
      const meili = results[2]
      send(200, {
        timestamp: new Date().toISOString(),
        services: {
          postgresql: db.status === 'fulfilled' ? { status: 'up', ...db.value } : { status: 'down', error: db.reason.message },
          redis: redis.status === 'fulfilled' ? { status: 'up', ...redis.value } : { status: 'down', error: redis.reason.message },
          meilisearch: meili.status === 'fulfilled' ? { status: 'up', ...meili.value } : { status: 'down', error: meili.reason.message },
        }
      })
    }
  }

  if (routes[path]) {
    routes[path]().catch(e => send(500, { error: e.message }))
  } else {
    send(404, { error: 'Not found', path })
  }
}

const server = require('http').createServer(handler)
server.listen(PORT, '0.0.0.0', () => {
  console.log(`API server listening on port ${PORT}`)
  console.log(`PostgreSQL: ${DATABASE_URL.replace(/\/\/.*@/, '//***@')}`)
  console.log(`Redis: ${REDIS_URL.replace(/\/\/.*@/, '//***@')}`)
  console.log(`Meilisearch: ${MEILISEARCH_HOST}`)
})