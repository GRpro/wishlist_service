#!/usr/bin/env bash
set -euo pipefail

COMPOSE_FILE="./docker-compose.yml"

if [ ! -f "$COMPOSE_FILE" ]; then
  echo "Error: $COMPOSE_FILE not found in current directory"
  exit 1
fi

echo "WARNING: This will permanently delete all DB volumes for this compose project."
echo "Project file: $COMPOSE_FILE"
echo
read -r -p "Type YES to continue: " CONFIRM

if [ "$CONFIRM" != "YES" ]; then
  echo "Aborted."
  exit 0
fi

echo "Stopping compose and removing containers, network and volumes..."
docker compose -f "$COMPOSE_FILE" down -v --remove-orphans

echo "DB volumes removed."