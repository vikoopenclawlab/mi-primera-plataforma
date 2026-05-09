#!/usr/bin/env bash
# First-time setup for local development environment
# Usage: ./setup-local.sh

set -euo pipefail

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

log_info() { echo -e "${GREEN}[INFO]${NC} $1"; }
log_warn() { echo -e "${YELLOW}[WARN]${NC} $1"; }
log_error() { echo -e "${RED}[ERROR]${NC} $1"; }

check_tool() {
    if ! command -v "$1" &> /dev/null; then
        log_error "$1 not found. Please install: $2"
        return 1
    fi
    return 0
}

setup_kubectl() {
    log_info "Setting up kubectl..."

    # Check if kubeconfig exists
    if [[ -f ~/.kube/config ]]; then
        log_info "kubeconfig found"
    else
        log_warn "No kubeconfig found. Please configure kubectl:"
        echo "  mkdir -p ~/.kube"
        echo "  # Copy k3s kubeconfig from your cluster"
        echo "  # Or for docker-desktop: kubectl config view --raw > ~/.kube/config"
    fi

    # Check cluster connectivity
    if kubectl cluster-info &>/dev/null; then
        log_info "✅ Connected to cluster"
        kubectl get nodes
    else
        log_warn "Cannot connect to cluster"
    fi
}

setup_docker() {
    log_info "Setting up Docker..."

    if ! docker info &>/dev/null; then
        log_error "Docker not running"
        return 1
    fi

    log_info "✅ Docker available"
    docker --version
}

setup_ghcr() {
    log_info "Setting up GHCR access..."

    # Login to GHCR
    if docker login ghcr.io -u "$USER" 2>/dev/null; then
        log_info "✅ Logged in to GHCR"
    else
        log_warn "Could not login to GHCR. You may need to create a GitHub token."
        echo "  Create token: https://github.com/settings/tokens"
        echo "  Then: docker login ghcr.io"
    fi
}

setup_local_dns() {
    log_info "Setting up local DNS entries..."

    # For development, add to /etc/hosts
    local hosts="# Stack Plataformas Web Development
127.0.0.1 app.plataformas.example.com
127.0.0.1 api.plataformas.example.com
127.0.0.1 staging.plataformas.example.com
"

    if grep -q "plataformas.example.com" /etc/hosts 2>/dev/null; then
        log_info "Hosts entries already exist"
    else
        log_warn "Please add to /etc/hosts:"
        echo "$hosts"
    fi
}

create_namespace() {
    log_info "Creating Kubernetes namespaces..."

    for ns in plataformas-web plataformas-web-staging plataformas-web-preview; do
        if kubectl get namespace "$ns" &>/dev/null; then
            log_info "  Namespace $ns exists"
        else
            kubectl create namespace "$ns"
            log_info "  Created namespace $ns"
        fi
    done
}

main() {
    log_info "🚀 Local Development Setup"
    echo ""

    # Check required tools
    log_info "Checking prerequisites..."
    check_tool kubectl "https://kubernetes.io/docs/tasks/tools/" || true
    check_tool docker "https://docs.docker.com/get-docker/" || true
    check_tool node "https://nodejs.org/" || true
    check_tool npm "npm comes with Node.js" || true

    echo ""

    # Setup components
    setup_docker
    setup_ghcr
    setup_kubectl
    setup_local_dns

    echo ""
    create_namespace

    echo ""
    log_info "✅ Setup complete!"
    echo ""
    echo "Next steps:"
    echo "  1. Copy .env.example to .env.local and configure"
    echo "  2. Run: docker compose up -d"
    echo "  3. Run migrations: docker compose exec api npx prisma migrate deploy"
    echo "  4. Visit: http://localhost:3000"
}

main "$@"