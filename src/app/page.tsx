export const dynamic = 'force-static'

export default function Home() {
  return (
    <main style={{ 
      fontFamily: 'system-ui, sans-serif',
      padding: '2rem',
      maxWidth: '800px',
      margin: '0 auto'
    }}>
      <h1>🚀 Mi Primera Plataforma</h1>
      <p style={{ color: '#666' }}>Bienvenido al stack de vikoopenclawlab</p>
      <pre style={{ 
        background: '#f4f4f4', 
        padding: '1rem', 
        borderRadius: '8px',
        fontSize: '0.85rem'
      }}>
Cluster: k3s HA (colima + i7-worker)
Namespace: plataformas-web
PostgreSQL: postgres.viko-apps.svc (db: mi_primera_plataforma)
Redis: redis.viko-apps.svc (db: 1)
NFS: /opt/shared-storage
      </pre>
    </main>
  )
}
