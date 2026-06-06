#!/usr/bin/env bash

set -euo pipefail

########################################
# CONFIGURATION
########################################

CONTAINER_NAME="mc-mc-1"
SERVER_ROOT="/home/minecraft/mc/data"
BACKUP_ROOT="/home/minecraft/backups"
RETENTION_DAYS=7
LOG_FILE="/home/minecraft/backup.log"

########################################
# RUNTIME VARIABLES
########################################

DATE=$(date +"%Y-%m-%d_%H-%M-%S")
CURRENT_BACKUP="$BACKUP_ROOT/$DATE"
LATEST_LINK="$BACKUP_ROOT/latest"

SAVES_DISABLED=false

########################################
# FUNCTIONS
########################################

log() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $1" | tee -a "$LOG_FILE"
}

restore_saves() {
    if [ "$SAVES_DISABLED" = true ]; then
        log "Restoring Minecraft save state..."
        docker exec "$CONTAINER_NAME" rcon-cli save-on || true
    fi
}

fail_cleanup() {
    log "Backup failed — running cleanup"
    restore_saves
}

########################################
# TRAP FAILURES
########################################

trap fail_cleanup ERR INT TERM EXIT

########################################
# START BACKUP
########################################

log "Starting Minecraft backup..."

mkdir -p "$CURRENT_BACKUP"

########################################
# VERIFY CONTAINER IS RUNNING
########################################

if ! docker ps --format '{{.Names}}' | grep -q "^${CONTAINER_NAME}$"; then
    fail "Container $CONTAINER_NAME is not running"
fi

########################################
# FREEZE WORLD STATE
########################################

log "Disabling world saves..."

docker exec "$CONTAINER_NAME" rcon-cli save-off
docker exec "$CONTAINER_NAME" rcon-cli save-all flush

SAVES_DISABLED=true

sleep 5

########################################
# INCREMENTAL RSYNC SNAPSHOT
########################################

log "Running rsync snapshot..."

if [ -L "$LATEST_LINK" ]; then
    rsync -a \
        --delete \
        --link-dest="$LATEST_LINK" \
        "$SERVER_ROOT/" \
        "$CURRENT_BACKUP/"
else
    rsync -a \
        "$SERVER_ROOT/" \
        "$CURRENT_BACKUP/"
fi

########################################
# RE-ENABLE SAVES
########################################

restore_saves
SAVES_DISABLED=false

########################################
# UPDATE LATEST SYMLINK
########################################

rm -f "$LATEST_LINK"
ln -s "$CURRENT_BACKUP" "$LATEST_LINK"

########################################
# CLEAN OLD BACKUPS
########################################

log "Removing backups older than $RETENTION_DAYS days..."

find "$BACKUP_ROOT" \
    -mindepth 1 \
    -maxdepth 1 \
    -type d \
    -mtime +$RETENTION_DAYS \
    -exec rm -rf {} \;

########################################
# COMPLETE
########################################

log "Backup completed successfully"
