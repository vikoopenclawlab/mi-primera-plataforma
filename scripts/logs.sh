#!/usr/bin/env bash
# Tail logs from Kubernetes pods
# Usage: ./logs.sh [app-name] [namespace] [lines]
# Examples:
#   ./logs.sh                    # Tail all apps
#   ./logs.sh nextjs dev         # Tail nextjs in dev
#   ./logs.sh api prod 200       # Tail api in prod with 200 lines

set -euo pipefail

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

APP="${1:-}"
NAMESPACE="${2:-plataformas-web}"
LINES="${3:-100}"

log_info() { echo -e "${GREEN}[INFO]${NC} $1"; }

# Tail logs for deployment
tail_deployment() {
    local app="$1"
    local ns="$2"
    local count="$3"

    log_info "Tailing logs: $app (namespace: $ns, lines: $count)"

    kubectl logs -n "$ns" -l app="$app" \
        --tail="$count" -f --timestamps 2>&1 | \
        while IFS= read -r line; do
            # Colorize by log level
            if echo "$line" | grep -qi "error"; then
                echo -e "\033[0;31m$line\033[0m"
            elif echo "$line" | grep -qi "warn"; then
                echo -e "\033[1;33m$line\033[0m"
            elif echo "$line" | grep -qi "debug"; then
                echo -e "\033[0;90m$line\033[0m"
            else
                echo "$line"
            fi
        done
}

main() {
    if [[ -z "$APP" ]]; then
        log_info "Tailing all applications in $NAMESPACE"
        for app in nextjs fastify-api; do
            if kubectl get deployment "$app" -n "$NAMESPACE" &>/dev/null; then
                echo -e "\n${GREEN}=== $app ===${NC}"
                kubectl logs -n "$NAMESPACE" -l app="$app" --tail=50 --timestamps 2>&1
            fi
        done
    else
        tail_deployment "$APP" "$NAMESPACE" "$LINES"
    fi
}

main "$@"