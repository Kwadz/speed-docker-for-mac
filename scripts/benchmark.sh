#!/usr/bin/env bash
set -euo pipefail

# Filesystem-performance benchmark for the running stack.
# Times a few realistic workloads inside the php-fpm container.
# Compare runs by toggling Mutagen on/off:
#   COMPOSE_CMD="docker compose"                                ./scripts/benchmark.sh
#   COMPOSE_CMD="mutagen-compose -f compose.yaml -f compose.mac.yaml" ./scripts/benchmark.sh

cd "$(dirname "$0")/.."

SERVICE="${SERVICE:-php-fpm}"

if [ "$(uname -s)" = "Darwin" ] && command -v mutagen-compose >/dev/null 2>&1 && [ -f compose.mac.yaml ]; then
    COMPOSE="${COMPOSE_CMD:-mutagen-compose -f compose.yaml -f compose.mac.yaml}"
else
    COMPOSE="${COMPOSE_CMD:-docker compose}"
fi

echo "=> Using: $COMPOSE"
echo

# High-precision wall clock. `date +%s.%N` is GNU-only and broken on macOS.
now() {
    perl -MTime::HiRes -e 'printf "%.6f\n", Time::HiRes::time'
}

# Time a command in the container; print "label   X.XXs"
run() {
    local label="$1"; shift
    printf "  %-32s " "$label"
    local start end
    start=$(now)
    "$@" >/dev/null 2>&1 || { echo "FAIL"; return 1; }
    end=$(now)
    awk -v s="$start" -v e="$end" 'BEGIN { printf "%6.2fs\n", e - s }'
}

ensure_up() {
    if ! $COMPOSE ps --status running --services 2>/dev/null | grep -q "^${SERVICE}$"; then
        echo "Service '$SERVICE' not running. Bring the stack up first (make up)." >&2
        exit 1
    fi
}

ensure_up

echo "Warming up..."
$COMPOSE exec -T "$SERVICE" sh -c 'true' >/dev/null

echo
echo "Benchmarks (this wipes vendor/ and var/cache/, then rebuilds them):"

# 1) Cold composer install (most punishing workload, writes thousands of small files)
run "composer install (cold)" \
    $COMPOSE exec -T "$SERVICE" sh -c '
        rm -rf vendor &&
        composer install --no-interaction --no-progress --quiet --no-scripts
    '

# 2) Full filesystem walk (read-heavy small-file workload, vendor now populated)
run "find /var/www -type f" \
    $COMPOSE exec -T "$SERVICE" sh -c 'find /var/www -type f | wc -l'

# 3) Symfony cache clear + warmup
run "cache:clear + cache:warmup" \
    $COMPOSE exec -T "$SERVICE" sh -c '
        rm -rf var/cache/* &&
        bin/console cache:warmup --quiet
    '

# 4) Write a thousand small files (sync stress test on writes)
run "write 1000 tiny files" \
    $COMPOSE exec -T "$SERVICE" sh -c '
        rm -rf /var/www/var/bench-tmp &&
        mkdir -p /var/www/var/bench-tmp &&
        for i in $(seq 1 1000); do echo "x" > /var/www/var/bench-tmp/f$i; done
    '

$COMPOSE exec -T "$SERVICE" rm -rf /var/www/var/bench-tmp >/dev/null 2>&1 || true

echo
echo "Done."
