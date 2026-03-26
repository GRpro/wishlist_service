#!/usr/bin/env bash
#run as "bash restore.sh ./restore_folder"
set -euo pipefail

COMPOSE_FILE="./docker-compose.yml"

if [ $# -ne 1 ]; then
  echo "Usage: bash restore.sh <backup_dir>"
  echo "Example: bash restore.sh ./backups/20260326_082221"
  exit 1
fi

BACKUP_DIR="$1"

if [ ! -d "$BACKUP_DIR" ]; then
  echo "Error: backup directory not found: $BACKUP_DIR"
  exit 1
fi

if [ ! -f "$COMPOSE_FILE" ]; then
  echo "Error: $COMPOSE_FILE not found in current directory"
  exit 1
fi

MONGO_BACKUP_DIR="$BACKUP_DIR/mongo"
NEO4J_DUMP_FILE="$BACKUP_DIR/neo4j.dump"
REDIS_RDB_FILE="$BACKUP_DIR/redis_dump.rdb"

if [ ! -d "$MONGO_BACKUP_DIR" ]; then
  echo "Error: Mongo backup directory not found: $MONGO_BACKUP_DIR"
  exit 1
fi

if [ ! -f "$NEO4J_DUMP_FILE" ]; then
  echo "Error: Neo4j dump file not found: $NEO4J_DUMP_FILE"
  exit 1
fi

if [ ! -f "$REDIS_RDB_FILE" ]; then
  echo "Error: Redis dump file not found: $REDIS_RDB_FILE"
  exit 1
fi

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
  echo "Stopping docker compose..."
  docker compose -f "$COMPOSE_FILE" down >/dev/null || true
}

trap cleanup EXIT

echo "Resetting docker compose..."
docker compose -f "$COMPOSE_FILE" down

echo "Starting docker compose..."
docker compose -f "$COMPOSE_FILE" up -d --wait

wait_ready

echo "[1/3] Restoring MongoDB..."
docker cp "$MONGO_BACKUP_DIR" wishlist_mongo:/tmp/mongorestore
docker exec wishlist_mongo sh -lc 'mongorestore --drop /tmp/mongorestore'

echo "[2/3] Restoring Redis..."
echo "Stopping Redis..."
docker stop wishlist_redis

echo "Copying Redis snapshot into Redis volume..."
docker run --rm \
  --volumes-from wishlist_redis \
  -v "$(realpath "$REDIS_RDB_FILE"):/backup/dump.rdb:ro" \
  alpine \
  sh -lc 'cp /backup/dump.rdb /data/dump.rdb && chown 999:999 /data/dump.rdb || true'

echo "Starting Redis..."
docker start wishlist_redis

echo "[3/3] Restoring Neo4j..."
echo "Stopping Neo4j..."
docker stop wishlist_neo4j

echo "Removing current Neo4j data..."
docker run --rm \
  --volumes-from wishlist_neo4j \
  alpine \
  sh -lc 'rm -rf /data/*'

echo "Loading Neo4j dump..."
docker run --rm \
  --volumes-from wishlist_neo4j \
  -v "$(realpath "$NEO4J_DUMP_FILE"):/backup/neo4j.dump:ro" \
  neo4j:5 \
  bash -lc '/var/lib/neo4j/bin/neo4j-admin database load neo4j --from-path=/backup --overwrite-destination=true'

echo "Starting Neo4j..."
docker start wishlist_neo4j

echo "Waiting for restored services..."
wait_ready

echo "Restore completed successfully"