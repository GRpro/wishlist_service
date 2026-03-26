#!/usr/bin/env bash
set -euo pipefail

COMPOSE_FILE="./docker-compose.yml"

TS=$(date +"%Y_%m_%d__%H_%M_%S")
OUT_DIR="./backups/$TS"
mkdir -p "$OUT_DIR"

DB_CONTAINERS=(
  "wishlist_mongo"
  "wishlist_redis"
  "wishlist_neo4j"
)

APP_CONTAINERS=(
  "wishlist_api"
  "reco_api"
  "wishlist_ui"
)

PAUSED=()

is_running() {
  local name="$1"
  docker inspect -f '{{.State.Running}}' "$name" 2>/dev/null | grep -q '^true$'
}

pause_apps() {
  for c in "${APP_CONTAINERS[@]}"; do
    if is_running "$c"; then
      echo "Pausing $c..."
      docker pause "$c" >/dev/null
      PAUSED+=("$c")
    fi
  done
}

unpause_apps() {
  for c in "${PAUSED[@]}"; do
    echo "Unpausing $c..."
    docker unpause "$c" >/dev/null || true
  done
}

wait_ready() {
  echo "Waiting for MongoDB..."
  timeout 60 bash -c '
    until docker exec wishlist_mongo mongosh --eval "db.runCommand({ ping: 1 })" >/dev/null 2>&1; do
      sleep 1
    done
  '

  echo "Waiting for Redis..."
  timeout 60 bash -c '
    until docker exec wishlist_redis redis-cli ping 2>/dev/null | grep -q PONG; do
      sleep 1
    done
  '

  echo "Waiting for Neo4j..."
  timeout 120 bash -c '
    until docker exec wishlist_neo4j cypher-shell -u neo4j -p testpassword123 "RETURN 1" >/dev/null 2>&1; do
      sleep 2
    done
  '

  echo "All DBs are ready"
}

cleanup() {
  unpause_apps
  echo "Stopping docker compose..."
  docker compose -f "$COMPOSE_FILE" down >/dev/null || true
}

trap cleanup EXIT

if [ ! -f "$COMPOSE_FILE" ]; then
  echo "Error: $COMPOSE_FILE not found in current directory"
  exit 1
fi

echo "Resetting docker compose..."
docker compose -f "$COMPOSE_FILE" down

echo "Starting docker compose..."
docker compose -f "$COMPOSE_FILE" up -d --wait

echo "Checking DB containers..."
for c in "${DB_CONTAINERS[@]}"; do
  if ! is_running "$c"; then
    echo "Error: $c is not running"
    exit 1
  fi
done

wait_ready
pause_apps

echo "[1/3] MongoDB dump..."
docker exec wishlist_mongo sh -lc 'rm -rf /tmp/mongodump && mongodump --out /tmp/mongodump'
docker cp wishlist_mongo:/tmp/mongodump "$OUT_DIR/mongo"

echo "[2/3] Neo4j dump (offline)..."

echo "Stopping Neo4j..."
docker stop wishlist_neo4j

echo "Dumping Neo4j database..."
docker run --rm \
  --volumes-from wishlist_neo4j \
  -v "$(pwd)/$OUT_DIR:/backup" \
  neo4j:5 \
  bash -lc '/var/lib/neo4j/bin/neo4j-admin database dump neo4j --to-path=/backup'

echo "[3/3] Redis snapshot..."
LASTSAVE_BEFORE=$(docker exec wishlist_redis redis-cli LASTSAVE | tr -d '\r')
docker exec wishlist_redis redis-cli BGSAVE >/dev/null

echo "Waiting Redis snapshot..."
while true; do
  LASTSAVE_AFTER=$(docker exec wishlist_redis redis-cli LASTSAVE | tr -d '\r')
  if [ "$LASTSAVE_AFTER" != "$LASTSAVE_BEFORE" ]; then
    break
  fi
  sleep 1
done

docker cp wishlist_redis:/data/dump.rdb "$OUT_DIR/redis_dump.rdb"

echo "Backup done: $OUT_DIR"