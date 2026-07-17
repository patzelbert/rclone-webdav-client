#!/usr/bin/env sh
# Watchdog / keep-alive loop (default container command).
#
# Replaces the old ls.sh, which only printed "Alive" and listed the mount
# directories without ever checking whether the FUSE mount was actually live.
#
# Each cycle it verifies every registered rclone FUSE mount. If ANY has died,
# it lazily tears them all down and EXITS so `restart: always` recreates the
# container and the entrypoint remounts everything fresh.
#
# Why restart instead of an in-place remount: the mounts are bind-propagated
# (rshared) to the host and onward to consumer containers (e.g. Photoprism).
# An in-place `rclone mount` recovers THIS container's view but does NOT
# propagate into an already-running consumer — verified: after an in-place
# remount the host and Photoprism still saw an empty directory. A container
# restart re-establishes the docker bind mount and its propagation, which does
# reach running consumers. So a dead mount => clean teardown => exit => restart.

PERIOD=${1:-30}

export LOG_FILE="${LOG_FILE:-/var/log/rclone.log}"
export CONFIG_FILE="${CONFIG_FILE:-/root/.config/rclone/rclone.conf}"
export REGISTRY="${REGISTRY:-/run/webdav/mounts}"

# shellcheck source=trap.sh
. /usr/local/bin/trap.sh
# shellcheck source=webdav-mount.sh
. /usr/local/bin/webdav-mount.sh

TAB=$(printf '\t')

while true; do
    down=""
    if [ -f "$REGISTRY" ]; then
        # `done < file` runs in the current shell (no subshell), so $down persists.
        while IFS="$TAB" read -r MOUNT_POINT URL; do
            [ -n "$MOUNT_POINT" ] || continue
            if is_fuse_mounted "$MOUNT_POINT"; then
                echo "OK   $MOUNT_POINT ($URL)"
            else
                echo "DOWN $MOUNT_POINT ($URL)"
                down="1"
            fi
        done < "$REGISTRY"
    else
        echo "WARN: mount registry $REGISTRY missing -- treating as down"
        down="1"
    fi

    if [ -n "$down" ]; then
        echo "-----------------------------------------------------------"
        echo "A WebDAV mount is DOWN -- tearing down and exiting so the"
        echo "container restarts and remounts cleanly (re-propagating to"
        echo "consumer containers)."
        echo "-----------------------------------------------------------"
        for m in /mnt/webdrive*; do
            [ -d "$m" ] && clear_mount "$m"
        done
        exit 1
    fi

    sleep "$PERIOD"
done
