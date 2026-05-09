#!/usr/bin/env bash
# Deploy to Kubernetes with rollout status verification
# Usage: ./deploy.sh [deployment] [namespace]
# Examples:
#   ./deploy.sh                    # Deploy all with default namespace
#   ./deploy.sh nextjs dev        # Deploy only nextjs to dev namespace

set -euo pipefail

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Defaults
DEPLOYMENT="${1:-}"
NAMESPACE="${2:-plataformas-web}"
TIMEOUT="600s"

# Helper functions
log_info() {
    echo -e "${GREEN}[INFO]${NC} $1"
}

log_warn() {
    echo -e "${YELLOW}[WARN]${NC} $1"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# Check prerequisites
check_prereqs() {
    if ! command -v kubectl &> /dev/null; then
        log_error "kubectl not found. Please install and configure kubectl."
        exit 1
    fi

    if ! kubectl cluster-info &> /dev/null; then
        log_error "Cannot connect to cluster. Check your kubeconfig."
        exit 1
    fi

    # Check namespace exists
    if ! kubectl get namespace "$NAMESPACE" &> /dev/null; then
        log_warn "Namespace '$NAMESPACE' does not exist. Creating..."
        kubectl create namespace "$NAMESPACE" --dry-run=client -o yaml | kubectl apply -f -
    fi
}

# Deploy using kustomize
deploy() {
    local target="${1:-}"
    local overlay="infra/k8s/overlays/${target:-dev}"

    log_info "Deploying from overlay: $overlay"

    if [[ ! -d "$overlay" ]]; then
        log_error "Overlay not found: $overlay"
        exit 1
    fi

    # Apply kustomization
    kubectl apply -k "$overlay" --namespace="$NAMESPACE"

    log_info "✅ Deployment applied. Waiting for rollout..."
}

# Wait for rollout
wait_rollout() {
    local deployment="$1"
    local ns="$2"

    log_info "Waiting for rollout of $deployment in $ns..."

    if ! kubectl rollout status "deployment/$deployment" \
        --namespace="$ns" \
        --timeout="$TIMEOUT"; then
        log_error "Rollout failed for $deployment"
        kubectl rollout history "deployment/$deployment" -n "$ns"
        exit 1
    fi

    log_info "✅ $deployment rollout complete"
}

# Verify deployment
verify() {
    local ns="$1"

    log_info "Verifying deployment in $ns..."

    # Check pod status
    local not_ready
    not_ready=$(kubectl get pods -n "$ns" --no-headers 2>/dev/null | grep -v "Running" | grep -v "Completed" || true)

    if [[ -n "$not_ready" ]]; then
        log_warn "Some pods are not ready:"
        echo "$not_ready"
    else
        log_info "✅ All pods running"
    fi

    # Show deployment info
    kubectl get deployments -n "$ns"
    kubectl get pods -n "$ns" -o wide
}

# Main
main() {
    local overlay="${DEPLOYMENT:-dev}"

    log_info "🚀 Starting deployment"
    log_info "Namespace: $NAMESPACE"
    log_info "Overlay: $overlay"

    check_prereqs

    # Apply deployment
    deploy "$overlay"

    # Wait for specific deployment or all
    if [[ -n "$DEPLOYMENT" ]]; then
        wait_rollout "$DEPLOYMENT" "$NAMESPACE"
    else
        # Wait for all deployments
        for dep in nextjs fastify-api; do
            if kubectl get deployment "$dep" -n "$NAMESPACE" &>/dev/null; then
                wait_rollout "$dep" "$NAMESPACE" || true
            fi
        done
    fi

    # Verify
    verify "$NAMESPACE"

    log_info "🎉 Deployment complete!"
}

main "$@"