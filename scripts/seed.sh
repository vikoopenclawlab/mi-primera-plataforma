#!/usr/bin/env bash
# Seed database with initial/fixture data
# Usage: ./seed.sh [namespace] [seed-file]

set -euo pipefail

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

NAMESPACE="${1:-plataformas-web}"
SEED_FILE="${2:-}"
SEED_POD="seed-$(date +%s)"

log_info() { echo -e "${GREEN}[INFO]${NC} $1"; }
log_error() { echo -e "${RED}[ERROR]${NC} $1"; }

run_seed() {
    log_info "Running database seed in namespace: $NAMESPACE"

    if [[ -n "$SEED_FILE" ]]; then
        log_info "Using seed file: $SEED_FILE"
        kubectl exec -n "$NAMESPACE" deploy/api -- \
            sh -c "npx prisma db seed -- --seed $SEED_FILE"
    else
        log_info "Running default seed..."
        kubectl exec -n "$NAMESPACE" deploy/api -- \
            sh -c "npx prisma db seed"
    fi

    log_info "✅ Seed complete"
}

verify_seed() {
    log_info "Verifying seed data..."

    # Check counts or run verification query
    kubectl exec -n "$NAMESPACE" deploy/api -- \
        sh -c "node -e \"console.log('Seed verification endpoint not implemented')\""
}

main() {
    if ! kubectl get deployment api -n "$NAMESPACE" &>/dev/null; then
        log_error "API deployment not found in $NAMESPACE"
        exit 1
    fi

    run_seed
    verify_seed
}

main "$@"