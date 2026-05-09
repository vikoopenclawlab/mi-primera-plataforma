#!/usr/bin/env bash
# Run Prisma migrations in Kubernetes
# Usage: ./migrate.sh [namespace] [command]
# Examples:
#   ./migrate.sh                        # Run deploy (production)
#   ./migrate.sh staging                # Run deploy in staging
#   ./migrate.sh dev "status"          # Check migration status

set -euo pipefail

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

NAMESPACE="${1:-plataformas-web}"
COMMAND="${2:-deploy}"
MIGRATION_POD="migration-$(date +%s)"

log_info() { echo -e "${GREEN}[INFO]${NC} $1"; }
log_warn() { echo -e "${YELLOW}[WARN]${NC} $1"; }
log_error() { echo -e "${RED}[ERROR]${NC} $1"; }

# Check for pending migrations
check_pending() {
    log_info "Checking for pending migrations..."

    local pending
    pending=$(kubectl exec -n "$NAMESPACE" deploy/api -- \
        sh -c "npx prisma migrate status --no-color 2>&1" 2>/dev/null || echo "unknown")

    echo "$pending"

    if echo "$pending" | grep -qi "pending"; then
        log_info "Found pending migrations"
        return 0
    elif echo "$pending" | grep -qi "applied"; then
        log_info "✅ All migrations applied"
        return 1
    fi

    return 0
}

# Run migration as job
run_migration_job() {
    log_info "Creating migration job..."

    kubectl run "$MIGRATION_POD" \
        --namespace="$NAMESPACE" \
        --image=ghcr.io/vikoopenclawlab/mi-primera-plataforma/nextjs:latest \
        --restart=Never \
        --rm -it \
        -- sh -c "npx prisma migrate $COMMAND --skip-generate"

    # Alternative: use exec on existing pod
    log_info "Running migration via existing API pod..."
}

# Run migration
run_migrate() {
    log_info "Running migrations in namespace: $NAMESPACE"
    log_info "Command: $COMMAND"

    # Create a temporary job for migration
    cat <<EOF | kubectl apply -f -
apiVersion: batch/v1
kind: Job
metadata:
  name: migrate-$(date +%s)
  namespace: $NAMESPACE
  labels:
    app: migrate
    date: $(date -Iseconds)
spec:
  ttlSecondsAfterFinished: 300
  template:
    spec:
      restartPolicy: Never
      containers:
        - name: migrate
          image: ghcr.io/vikoopenclawlab/mi-primera-plataforma/nextjs:latest
          command: ["sh", "-c", "npx prisma migrate $COMMAND"]
          envFrom:
            - configMapRef:
                name: api-config
            - secretRef:
                name: api-secrets
EOF

    log_info "Migration job created. Checking status..."
    kubectl wait --for=condition=complete job -n "$NAMESPACE" -l app=migrate --timeout=120s

    log_info "Checking migration results..."
    kubectl logs -n "$NAMESPACE" -l app=migrate --tail=50 || true

    # Show status
    kubectl exec -n "$NAMESPACE" deploy/api -- sh -c "npx prisma migrate status" 2>/dev/null || true
}

main() {
    case "$COMMAND" in
        status)
            log_info "Checking migration status..."
            kubectl exec -n "$NAMESPACE" deploy/api -- \
                sh -c "npx prisma migrate status" 2>/dev/null || \
                log_error "Could not check status"
            ;;
        resolve)
            log_info "Resolving migration issues..."
            local migration="${3:-}"
            if [[ -z "$migration" ]]; then
                log_error "Usage: ./migrate.sh <namespace> resolve <migration-name>"
                exit 1
            fi
            kubectl exec -n "$NAMESPACE" deploy/api -- \
                sh -c "npx prisma migrate resolve --applied $migration"
            ;;
        *)
            run_migrate
            ;;
    esac

    log_info "✅ Migration procedure complete"
}

main "$@"