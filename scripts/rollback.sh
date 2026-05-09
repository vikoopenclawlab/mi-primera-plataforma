#!/usr/bin/env bash
# Rollback to previous or specific version
# Usage: ./rollback.sh [deployment] [version]
# Examples:
#   ./rollback.sh                           # Rollback all deployments
#   ./rollback.sh nextjs                     # Rollback nextjs to previous
#   ./rollback.sh nextjs v1.1.0             # Rollback to specific version

set -euo pipefail

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

DEPLOYMENT="${1:-}"
NAMESPACE="${2:-plataformas-web}"

log_info() { echo -e "${GREEN}[INFO]${NC} $1"; }
log_warn() { echo -e "${YELLOW}[WARN]${NC} $1"; }
log_error() { echo -e "${RED}[ERROR]${NC} $1"; }

# Show history
show_history() {
    local dep="$1"
    local ns="$2"

    echo "=== Rollout History: $dep ==="
    kubectl rollout history "deployment/$dep" -n "$ns"
    echo ""
    echo "Recent revisions:"
    kubectl rollout history "deployment/$dep" -n "$ns" | tail -10
}

# Rollback
do_rollback() {
    local dep="$1"
    local ns="$2"
    local version="${3:-}"

    log_info "Rolling back $dep in $ns..."

    if [[ -n "$version" ]]; then
        log_info "Target version: $version"
        kubectl rollout undo "deployment/$dep" -n "$ns" --to-revision="$version"
    else
        log_info "Rolling back to previous revision"
        kubectl rollout undo "deployment/$dep" -n "$ns"
    fi

    # Wait for rollout
    log_info "Waiting for rollout to complete..."
    if ! kubectl rollout status "deployment/$dep" -n "$ns" --timeout=300s; then
        log_error "Rollout failed"
        kubectl describe pod -n "$ns" -l app="$dep"
        exit 1
    fi

    log_info "✅ Rollback complete for $dep"
}

# Verify
verify() {
    local ns="$1"
    log_info "Pod status:"
    kubectl get pods -n "$ns" -l app="$DEPLOYMENT" 2>/dev/null || kubectl get pods -n "$ns"
}

main() {
    log_info "🔄 Starting rollback"
    log_info "Deployment: ${DEPLOYMENT:-all}"
    log_info "Namespace: $NAMESPACE"

    if [[ -z "$DEPLOYMENT" ]]; then
        # Rollback all
        for dep in nextjs fastify-api; do
            if kubectl get deployment "$dep" -n "$NAMESPACE" &>/dev/null; then
                show_history "$dep" "$NAMESPACE"
                do_rollback "$dep" "$NAMESPACE"
            fi
        done
    else
        show_history "$DEPLOYMENT" "$NAMESPACE"
        do_rollback "$DEPLOYMENT" "$NAMESPACE" "${3:-}"
    fi

    verify "$NAMESPACE"
    log_info "✅ Rollback procedure complete"
}

main "$@"