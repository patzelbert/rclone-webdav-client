#!/usr/bin/env sh
# Shared WebDAV mount helpers for rclone-webdav-client.
# Sourced by docker-entrypoint.sh (initial mount), watchdog.sh (remount) and
# healthcheck.sh (liveness).

LOG_FILE="${LOG_FILE:-/var/log/rclone.log}"
CONFIG_FILE="${CONFIG_FILE:-/root/.config/rclone/rclone.conf}"
REGISTRY="${REGISTRY:-/run/webdav/mounts}"

# Stable, unique rclone remote name derived from the mount point.
remote_name() {
    echo "webdav_remote_$(echo "$1" | tr '/' '_')"
}

# is_fuse_mounted <mount_point>
# True ONLY when a FUSE (rclone) filesystem is mounted at the path. NOTE: a
# plain `mountpoint -q` is NOT sufficient here — each mount point is a bind
# mount, so it is always a "mountpoint" even after the rclone daemon dies and
# only the empty backing directory remains. We must confirm the fuse overlay.
is_fuse_mounted() {
    mount 2>/dev/null | grep -qE " on $1 type fuse"
}

# clear_mount <mount_point>
# Lazily detach whatever is on the mount point so a fresh mount can be placed.
# Lazy (-z / -l) avoids "Resource busy" when a handle is still open and cleans
# up the mount that propagated to the host via rshared.
clear_mount() {
    fusermount3 -uz "$1" 2>/dev/null || fusermount -uz "$1" 2>/dev/null
    umount -l "$1" 2>/dev/null
    return 0
}

# mount_one <mount_point> <url> <username> <password>
# Creates/refreshes the rclone remote and (re)mounts it. Returns 0 once the
# rclone FUSE mount is verified live, non-zero otherwise (caller decides).
mount_one() {
    MOUNT_POINT=$1
    URL=$2
    USERNAME=$3
    PASSWORD=$4

    NAME=$(remote_name "$MOUNT_POINT")
    mkdir -p "$MOUNT_POINT"

    # Recreate the remote definition (idempotent).
    rclone config delete "$NAME" --config "$CONFIG_FILE" 2>/dev/null
    rclone config create "$NAME" webdav url "$URL" vendor other \
        user "$USERNAME" pass "$PASSWORD" \
        --log-file="$LOG_FILE" --config "$CONFIG_FILE"

    # Resilience flags for slow/flaky WebDAV servers (e.g. Seafile seafdav on
    # large flat directories): generous timeouts + retries and a longer dir
    # cache so an intermittently truncated listing recovers instead of leaving
    # the mount empty. Single transfer keeps load off a fragile server.
    rclone mount "$NAME:" "$MOUNT_POINT" \
        --vfs-cache-mode full --uid "$UID" --gid "$GID" \
        --dir-perms 755 --file-perms 755 \
        --timeout 90s --contimeout 60s --low-level-retries 20 \
        --dir-cache-time 10m --transfers 1 \
        --log-file="$LOG_FILE" --daemon --allow-non-empty --allow-other \
        --config "$CONFIG_FILE"

    # Wait up to ~15s for the rclone FUSE mount to actually come live.
    i=0
    while [ "$i" -lt 15 ]; do
        if is_fuse_mounted "$MOUNT_POINT"; then
            return 0
        fi
        i=$((i + 1))
        sleep 1
    done
    return 1
}
