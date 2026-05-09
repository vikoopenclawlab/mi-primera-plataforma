#!/usr/bin/env bash
# Cleanup old Docker images and prune system
# Usage: ./cleanup.sh [--dry-run|--confirm]

set -euo pipefail

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

MODE="dry-run"
RETENTION_DAYS=30

while [[ $# -gt 0 ]]; do
    case "$1" in
        --dry-run)
            MODE="dry-run"
            shift
            ;;
        --confirm)
            MODE="confirm"
            shift
            ;;
        --days)
            RETENTION_DAYS="$2"
            shift 2
            ;;
        *)
            shift
            ;;
    esac
done

log_info() { echo -e "${GREEN}[INFO]${NC} $1"; }
log_warn() { echo -e "${YELLOW}[WARN]${NC} $1"; }
log_error() { echo -e "${RED}[ERROR]${NC} $1"; }

cleanup_docker() {
    log_info "Cleaning Docker images..."

    local before
    before=$(docker images -q | wc -l)
    log_info "Images before: $before"

    if [[ "$MODE" == "dry-run" ]]; then
        log_warn "[DRY RUN] Would prune:"
        docker image prune -a --filter "until=${RETENTION_DAYS}d" --dry-run
    else
        log_info "Pruning images older than $RETENTION_DAYS days..."
        docker image prune -a --filter "until=${RETENTION_DAYS}d"
    fi

    local after
    after=$(docker images -q | wc -l)
    log_info "Images after: $after"
}

cleanup_builder() {
    log_info "Cleaning builder cache..."

    if [[ "$MODE" == "dry-run" ]]; then
        log_warn "[DRY RUN] Would prune builder cache"
        docker builder prune --dry-run
    else
        docker builder prune -a
    fi
}

cleanup_volumes() {
    log_info "Checking for unused volumes..."

    local unused
    unused=$(docker volume ls -qf dangling=true | wc -l)

    if [[ "$unused" -gt 0 ]]; then
        log_warn "Found $unused unused volumes"
        if [[ "$MODE" == "confirm" ]]; then
            log_info "Removing dangling volumes..."
            docker volume prune
        fi
    fi
}

cleanup_system() {
    log_info "Pruning system..."

    if [[ "$MODE" == "dry-run" ]]; then
        log_warn "[DRY RUN] Would prune:"
        docker system prune --dry-run
    else
        docker system prune -f
    fi
}

show_disk_usage() {
    log_info "Docker disk usage:"
    docker system df
}

main() {
    log_info "🧹 Cleanup Script"
    log_info "Mode: $MODE"
    log_info "Retention: $RETENTION_DAYS days"
    echo ""

    if [[ "$MODE" == "dry-run" ]]; then
        log_warn "Running in DRY RUN mode. Use --confirm to actually delete."
    fi

    show_disk_usage
    echo ""
    cleanup_docker
    echo ""
    cleanup_builder
    echo ""
    cleanup_volumes
    echo ""
    cleanup_system
    echo ""

    show_disk_usage
    log_info "✅ Cleanup complete"
}

main "$@"