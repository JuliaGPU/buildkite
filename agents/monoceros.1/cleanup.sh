#!/bin/bash
# Julia depot cleanup for the macOS Metal agents: removes least-recently-used
# depot directories when disk usage exceeds the threshold. macOS adaptation of
# the cron.daily script on the Linux agents (BSD stat/df instead of GNU find
# -printf), run daily by the cleanup LaunchDaemon as the julia user.
set -euo pipefail

CACHE="/Users/julia/cache"
DEPOTS="${CACHE}/julia/depots"
THRESHOLD_PERCENT=75
LOG_FILE="/Users/julia/cleanup.log"
DRY_RUN="${DRY_RUN:-false}"

log() {
    echo "$(date '+%Y-%m-%d %H:%M:%S') - $1" | tee -a "$LOG_FILE"
}

get_disk_usage() {
    df -P "$CACHE" | awk 'NR==2 {gsub(/%/, "", $5); print $5}'
}

# Depot directories (one per pipeline ID), least recently used first. The
# julia-buildkite-plugin touches a depot at the start of every job that uses
# it, so mtime ordering is LRU ordering.
get_depot_dirs() {
    find "$DEPOTS" -mindepth 1 -maxdepth 1 -type d -exec stat -f '%m %N' {} + \
        2>/dev/null | sort -n | cut -d' ' -f2-
}

get_dir_size() {
    du -sh "$1" 2>/dev/null | cut -f1 || echo "unknown"
}

cleanup_depots() {
    local current_usage
    current_usage=$(get_disk_usage)

    log "Starting cleanup check. Current usage: ${current_usage}%"

    if [[ $current_usage -lt $THRESHOLD_PERCENT ]]; then
        log "Disk usage (${current_usage}%) is below threshold (${THRESHOLD_PERCENT}%). No cleanup needed."
        return 0
    fi

    log "Disk usage (${current_usage}%) exceeds threshold (${THRESHOLD_PERCENT}%). Starting cleanup..."

    local depot_dirs
    depot_dirs=$(get_depot_dirs)

    if [[ -z "$depot_dirs" ]]; then
        log "Warning: No depot directories found in ${DEPOTS}"
        return 1
    fi

    local now
    now=$(date +%s)
    local dirs_removed=0

    while IFS= read -r dir; do
        current_usage=$(get_disk_usage)

        if [[ $current_usage -lt $THRESHOLD_PERCENT ]]; then
            log "Target usage achieved (${current_usage}%). Stopping cleanup."
            break
        fi

        if [[ ! -d "$dir" ]]; then
            log "Warning: Directory no longer exists: $dir"
            continue
        fi

        # A depot touched in the last 24 hours may belong to a running job
        if [[ $(stat -f '%m' "$dir") -gt $((now - 24*60*60)) ]]; then
            log "Skipping recently-used depot: $dir"
            continue
        fi

        local dir_size
        dir_size=$(get_dir_size "$dir")

        log "Removing depot directory: $dir (size: $dir_size)"

        if [[ "$DRY_RUN" == "true" ]]; then
            log "DRY RUN: Would remove $dir"
        else
            # Julia artifact directories are read-only
            chmod -R u+w "$dir" 2>/dev/null
            if rm -rf "$dir" 2>/dev/null; then
                dirs_removed=$((dirs_removed + 1))
                log "Successfully removed: $dir"
            else
                log "Error: Failed to remove $dir"
            fi
        fi
    done <<< "$depot_dirs"

    current_usage=$(get_disk_usage)
    log "Cleanup completed. Removed $dirs_removed directories. Final usage: ${current_usage}%"

    if [[ $current_usage -ge $THRESHOLD_PERCENT ]]; then
        log "Warning: Usage still above threshold after removing all eligible depots"
        return 1
    fi

    return 0
}

if ! touch "$LOG_FILE" 2>/dev/null; then
    echo "Error: Cannot write to log file $LOG_FILE"
    exit 1
fi

if [[ ! -d "$DEPOTS" ]]; then
    log "No depot directory at ${DEPOTS}; nothing to clean up"
    exit 0
fi

if cleanup_depots; then
    log "Cleanup job completed successfully"
    exit 0
else
    log "Cleanup job completed with warnings/errors"
    exit 1
fi
