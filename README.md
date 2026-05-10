# Template: Next.js + Fastify

> Stack de aplicación web multi-tenant para rápido bootstrapping.  
> *Last reviewed: 2026-05-04*

---

## 🏗️ Estructura del Proyecto

```
nextjs-fastify/
├── docker/
│   ├── Containerfile          # Multi-stage build
│   ├── docker-compose.yml     # Local development
│   └── docker-compose.prod.yml # Production
├── k8s/
│   ├── deployment.yaml
│   ├── service.yaml
│   ├── ingress.yaml
│   ├── configmap.yaml
│   ├── secrets.yaml
│   ├── hpa.yaml
│   ├── pdb.yaml
│   ├── networkpolicy.yaml
│   └── kustomization.yaml
├── scripts/
│   ├── deploy.sh
│   ├── rollback.sh
│   ├── migrate.sh
│   ├── seed.sh
│   ├── logs.sh
│   ├── smoke-test.sh
│   ├── setup-local.sh
│   └── cleanup.sh
├── .github/
│   └── workflows/
│       ├── ci.yml
│       ├── cd.yml
│       ├── release.yml
│       └── cleanup.yml
├── prisma/
│   └── schema.prisma
└── package.json
```

---

## 🔧 Setup Inicial

### 1. Clonar el template

```bash
# Copiar el template a tu nuevo proyecto
cp -r template/nextjs-fastify /path/to/your-new-project
cd /path/to/your-new-project
```

### 2. Personalizar

```bash
# Renombrar proyecto en package.json
export PROJECT_NAME="tu-proyecto"
sed -i '' "s/mi-primera-plataforma/$PROJECT_NAME/g" docker/Containerfile
sed -i '' "s/mi-primera-plataforma/$PROJECT_NAME/g" docker/docker-compose*.yml
sed -i '' "s/mi-primera-plataforma/$PROJECT_NAME/g" k8s/*.yaml
```

### 3. Variables de ambiente

```bash
# Copiar template de env
cp .env.example .env.local

# Editar con tus valores
vim .env.local
```

**Variables requeridas:**

```env
# Database
DATABASE_URL="postgresql://postgres:changeme@localhost:5432/app?schema=public"

# Redis
REDIS_URL="redis://localhost:6379"

# Meilisearch
MEILISEARCH_HOST="http://localhost:7700"
MEILISEARCH_API_KEY="changeme"

# App
NEXT_PUBLIC_API_URL="http://localhost:4000"
NODE_ENV="development"
```

---

## 🐳 Desarrollo Local con Docker Compose

### Up

```bash
cd docker
docker compose up -d

# Verificar logs
docker compose logs -f
```

### Servicios

| Servicio | Puerto | Descripción |
|----------|--------|-------------|
| nextjs | 3000 | Frontend Next.js |
| api | 4000 | Backend Fastify |
| postgres | 5432 | PostgreSQL 16 |
| redis | 6379 | Redis 7 |
| meilisearch | 7700 | Motor de búsqueda |
| traefik | 80, 443 | Reverse proxy |

### Migraciones

```bash
docker compose exec api npx prisma migrate deploy
```

### Seed

```bash
docker compose exec api npx prisma db seed
```

### Down

```bash
docker compose down -v  # -v para destruir volúmenes
```

### Troubleshooting

```bash
# Ver estado
docker compose ps

# Logs de servicio específico
docker compose logs postgres

# Reiniciar servicio
docker compose restart nextjs

# Rebuild sin cache
docker compose build --no-cache
```

---

## 🚀 Despliegue a Kubernetes

### Pre-requisitos

- kubectl configurado con acceso al cluster
- k3s cluster disponible
- GHCR credentials configuradas

### Setup local

```bash
./scripts/setup-local.sh
```

### Deploy

```bash
# Ver overlays disponibles
ls infra/k8s/overlays/

# Deploy a dev
kubectl apply -k infra/k8s/overlays/dev

# Deploy a staging
kubectl apply -k infra/k8s/overlays/staging

# Deploy a prod (con confirmación)
kubectl apply -k infra/k8s/overlays/prod
```

### Verificar deploy

```bash
# Script de smoke test
./scripts/smoke-test.sh

# Ver pods
kubectl get pods -n plataformas-web

# Ver rollout status
kubectl rollout status deployment/nextjs -n plataformas-web
```

---

## 📦 CI/CD Workflows

### CI (Pull Request)

```
PR opened/updated
    ↓
Lint + Typecheck
    ↓
Test (unit + integration)
    ↓
Build Docker image (cached)
    ↓
Security scan (Trivy)
    ↓
Push preview image: sha-<commit>
    ↓
Deploy preview env (ephemeral)
    ↓
Report status
```

### CD (Push to main)

```
Push to main
    ↓
CI pipeline (lint, test, build)
    ↓
Push image: latest + sha-<commit>
    ↓
Deploy to staging
    ↓
Smoke tests
    ↓
Notify #deployments
```

### Release (Tag v*)

```
Tag v1.2.3 pushed
    ↓
Build + scan production image
    ↓
Push with version tag
    ↓
Deploy to staging
    ↓
Approval gate (manual)
    ↓
Deploy to production (rolling)
    ↓
Smoke tests
    ↓
Notify success
```

---

## 🔄 Rollback

```bash
# Rollback al último deployment bueno
./scripts/rollback.sh

# Rollback a versión específica
./scripts/rollback.sh nextjs v1.1.0

# Ver historial
kubectl rollout history deployment/nextjs -n plataformas-web
```

---

## 🧹 Cleanup

```bash
# Dry run
./scripts/cleanup.sh --dry-run

# Confirm cleanup
./scripts/cleanup.sh --confirm
```

---

## 🎯 Checklist de Deploy

- [ ] `.env.local` configurado
- [ ] Docker Compose up localmente funciona
- [ ] `docker compose exec api npx prisma migrate deploy` exitoso
- [ ] `docker compose exec api npm run seed` exitoso (si hay datos)
- [ ] Smoke test pasa localmente
- [ ] K8s manifests correctos (namespace, imagen tag, recursos)
- [ ] Secrets configurados (no hardcodeados)
- [ ] CI/CD pipelines activos en GitHub

---

*Last reviewed: 2026-05-04*# Test commit
