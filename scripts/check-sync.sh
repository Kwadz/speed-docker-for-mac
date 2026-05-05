#!/usr/bin/env bash
set -euo pipefail

# Verifies that file changes propagate between host and container in both directions.
# Useful right after `make up` to confirm the sync layer is healthy.

cd "$(dirname "$0")/.."

HOST_DIR="./app"
CONTAINER_PATH="/var/www"
SERVICE="${SERVICE:-php-fpm}"
TIMEOUT="${TIMEOUT:-10}"

if [ "$(uname -s)" = "Darwin" ] && command -v mutagen-compose >/dev/null 2>&1 && [ -f compose.mac.yaml ]; then
    COMPOSE="${COMPOSE_CMD:-mutagen-compose -f compose.yaml -f compose.mac.yaml}"
else
    COMPOSE="${COMPOSE_CMD:-docker compose}"
fi

cleanup() {
    rm -f "${HOST_DIR}/.sync-test-host" 2>/dev/null || true
    $COMPOSE exec -T "$SERVICE" rm -f "${CONTAINER_PATH}/.sync-test-host" "${CONTAINER_PATH}/.sync-test-container" 2>/dev/null || true
    rm -f "${HOST_DIR}/.sync-test-container" 2>/dev/null || true
}
trap cleanup EXIT

echo "=> Using: $COMPOSE"

# Direction 1: host -> container
sentinel="host-$(date +%s%N)"
echo "$sentinel" > "${HOST_DIR}/.sync-test-host"
echo -n "host -> container... "
for i in $(seq 1 "$TIMEOUT"); do
    if $COMPOSE exec -T "$SERVICE" cat "${CONTAINER_PATH}/.sync-test-host" 2>/dev/null | grep -q "$sentinel"; then
        echo "OK in ${i}s"
        break
    fi
    sleep 1
    if [ "$i" = "$TIMEOUT" ]; then
        echo "FAIL (timeout ${TIMEOUT}s)" >&2
        exit 1
    fi
done

# Direction 2: container -> host
sentinel="container-$(date +%s%N)"
$COMPOSE exec -T "$SERVICE" sh -c "echo $sentinel > ${CONTAINER_PATH}/.sync-test-container"
echo -n "container -> host... "
for i in $(seq 1 "$TIMEOUT"); do
    if grep -q "$sentinel" "${HOST_DIR}/.sync-test-container" 2>/dev/null; then
        echo "OK in ${i}s"
        echo
        echo "Sync is functional in both directions."
        exit 0
    fi
    sleep 1
done

echo "FAIL (timeout ${TIMEOUT}s)" >&2
exit 1
