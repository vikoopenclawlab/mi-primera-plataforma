const fastify = require('fastify')({ logger: true })

// Health check
fastify.get('/api/health', async (req, reply) => {
  return { status: 'ok', service: 'fastify-api', timestamp: new Date().toISOString() }
})

// Status con info de conexión a PostgreSQL y Redis
fastify.get('/api/status', async (req, reply) => {
  const { Client } = require('pg')
  const Redis = require('ioredis')
  
  let pgStatus = 'unknown'
  let redisStatus = 'unknown'
  
  // Test PostgreSQL
  try {
    const client = new Client({
      connectionString: process.env.DATABASE_URL,
      connectionTimeoutMillis: 3000
    })
    await client.connect()
    await client.query('SELECT 1')
    await client.end()
    pgStatus = 'connected'
  } catch (e) {
    pgStatus = 'error: ' + e.message
  }
  
  // Test Redis
  try {
    const redis = new Redis(process.env.REDIS_URL, { connectTimeout: 3000 })
    await redis.ping()
    await redis.quit()
    redisStatus = 'connected'
  } catch (e) {
    redisStatus = 'error: ' + e.message
  }
  
  return {
    service: 'fastify-api',
    timestamp: new Date().toISOString(),
    postgres: pgStatus,
    redis: redisStatus,
    version: '1.0.0'
  }
})

// Test Meilisearch
fastify.get('/api/search-health', async (req, reply) => {
  const { MeiliSearch } = require('meilisearch')
  try {
    const client = new MeiliSearch({ host: process.env.MEILISEARCH_HOST })
    await client.health()
    return { meilisearch: 'connected' }
  } catch (e) {
    return { meilisearch: 'error: ' + e.message }
  }
})

// Echo endpoint para testing
fastify.post('/api/echo', async (req, reply) => {
  return { received: req.body, timestamp: new Date().toISOString() }
})

const start = async () => {
  try {
    await fastify.listen({ port: 4000, host: '0.0.0.0' })
    console.log('Fastify API running on port 4000')
  } catch (err) {
    fastify.log.error(err)
    process.exit(1)
  }
}

start()
