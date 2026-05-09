#!/usr/bin/env bash
# Smoke test for deployment verification
# Usage: ./smoke-test.sh [--env staging|production|preview]

set -euo pipefail

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

ENV="staging"
ENDPOINTS=()

while [[ $# -gt 0 ]]; do
    case "$1" in
        --env)
            ENV="$2"
            shift 2
            ;;
        *)
            shift
            ;;
    esac
done

case "$ENV" in
    staging)
        ENDPOINTS=(
            "https://staging.plataformas.example.com/health"
            "https://api.plataformas.example.com/health"
        )
        ;;
    production)
        ENDPOINTS=(
            "https://app.plataformas.example.com/health"
            "https://api.plataformas.example.com/health"
        )
        ;;
    preview)
        ENDPOINTS=(
            "http://localhost:3000/health"
            "http://localhost:4000/health"
        )
        ;;
    local)
        ENDPOINTS=(
            "http://localhost:3000/health"
            "http://localhost:4000/health"
        )
        ;;
esac

FAILED=0

log_info() { echo -e "${GREEN}[INFO]${NC} $1"; }
log_error() { echo -e "${RED}[ERROR]${NC} $1"; }
log_warn() { echo -e "${YELLOW}[WARN]${NC} $1"; }

# Test single endpoint
test_endpoint() {
    local url="$1"
    local name="$2"

    echo -n "Testing $name... "

    response=$(curl -s -w "\n%{http_code}" "$url" 2>/dev/null || echo "000")
    code=$(echo "$response" | tail -1)
    body=$(echo "$response" | head -1)

    if [[ "$code" == "200" ]]; then
        # Validate response
        if echo "$body" | grep -qi "ok\|healthy\|200"; then
            echo -e "${GREEN}✅ PASS${NC}"
            return 0
        else
            echo -e "${YELLOW}⚠ WARN${NC} (200 but unexpected body)"
            return 0
        fi
    else
        echo -e "${RED}❌ FAIL${NC} (HTTP $code)"
        return 1
    fi
}

main() {
    log_info "🔍 Running smoke tests for environment: $ENV"
    echo ""

    if [[ ${#ENDPOINTS[@]} -eq 0 ]]; then
        log_error "No endpoints configured for environment: $ENV"
        exit 1
    fi

    # Test each endpoint
    for endpoint in "${ENDPOINTS[@]}"; do
        name=$(echo "$endpoint" | awk -F/ '{print $NF}')
        if ! test_endpoint "$endpoint" "$name"; then
            FAILED=$((FAILED + 1))
        fi
    done

    echo ""
    if [[ $FAILED -eq 0 ]]; then
        log_info "✅ All smoke tests passed!"
        exit 0
    else
        log_error "❌ $FAILED smoke test(s) failed"
        exit 1
    fi
}

main "$@"