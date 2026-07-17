#!/usr/bin/env sh
echo "-----------------RClone Webdav Client-----------------"
echo ' '
touch /var/log/rclone.log

SUCCESS_FILE=/usr/local/bin/mounted
rm -f "$SUCCESS_FILE"

export LOG_FILE="/var/log/rclone.log"
export CONFIG_FILE="/root/.config/rclone/rclone.conf"
export REGISTRY="/run/webdav/mounts"

mkdir -p "$(dirname "$CONFIG_FILE")" "$(dirname "$REGISTRY")"
: > "$REGISTRY"

# shellcheck source=webdav-mount.sh
. /usr/local/bin/webdav-mount.sh

# Read in array of URLs; split the string by commas if a comma is present.
URLS=${WEBDRIVE_URLS//,/ }

# Username and password are the same for all URLs.
USERNAME="$WEBDRIVE_USERNAME"
PASSWORD="$WEBDRIVE_PASSWORD"

index=1
for url in $URLS; do
    MOUNT_POINT="/mnt/webdrive$index"
    echo ' '
    echo "-----------------------Mounting-----------------------"
    echo ' '
    echo "mounting $url -> $MOUNT_POINT"
    if mount_one "$MOUNT_POINT" "$url" "$USERNAME" "$PASSWORD"; then
        echo "Mounted $url onto $MOUNT_POINT"
        # Record the live mapping so the watchdog can remount if it dies.
        printf '%s\t%s\n' "$MOUNT_POINT" "$url" >> "$REGISTRY"
    else
        # No silent fallback: a failed mount fails the container loudly.
        echo "ERROR: mounting $url onto $MOUNT_POINT failed!"
        tail -n 40 "$LOG_FILE"
        exit 1
    fi
    index=$((index + 1))
done

# Notify other containers that all mounts are up.
touch "$SUCCESS_FILE"

exec "$@"
