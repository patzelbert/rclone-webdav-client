#!/usr/bin/env sh
# Container healthcheck: healthy ONLY if every configured WebDAV mount has a
# live rclone FUSE overlay. This replaces the old "test -f /usr/local/bin/mounted"
# check, which stayed true forever after the first mount and reported "healthy"
# even after the FUSE mounts had died. A plain `mountpoint -q` is likewise not
# enough (the bind mount is always a mountpoint), so we reuse is_fuse_mounted.

export REGISTRY="${REGISTRY:-/run/webdav/mounts}"

# shellcheck source=webdav-mount.sh
. /usr/local/bin/webdav-mount.sh

[ -f "$REGISTRY" ] || exit 1

n=0
TAB=$(printf '\t')
while IFS="$TAB" read -r MP URL; do
    [ -n "$MP" ] || continue
    n=$((n + 1))
    is_fuse_mounted "$MP" || exit 1
done < "$REGISTRY"

# Must have at least one mount, and (by the loop above) all must be live.
[ "$n" -gt 0 ] || exit 1
exit 0
