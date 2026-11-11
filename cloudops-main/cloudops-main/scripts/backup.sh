#!/bin/bash

set -e

BACKUP_DIR="./backups"
TIMESTAMP=$(date +%Y%m%d_%H%M%S)
BACKUP_FILE="$BACKUP_DIR/postgres_backup_$TIMESTAMP.sql"

mkdir -p $BACKUP_DIR

echo ">>> Checking database pod status..."
DB_POD=$(kubectl get pod -l app=db -o jsonpath="{.items[0].metadata.name}")

if [ -z "$DB_POD" ]; then
  echo "Error: No database pod found. Is the db deployment running?"
  exit 1
fi

echo ">>> Found pod: $DB_POD"
echo ">>> Starting backup to: $BACKUP_FILE"

kubectl exec $DB_POD -- \
  pg_dump -U myuser mydatabase >$BACKUP_FILE

echo ">>> Backup complete!"
echo ">>> File: $BACKUP_FILE"
echo ">>> Size: $(du -sh $BACKUP_FILE | cut -f1)"
