#! /usr/bin/env sh

PERIOD=${1:-60}
. trap.sh

while true; do
    for MOUNT_POINT in /mnt/webdrive*; do
        if [ -d "$MOUNT_POINT" ]; then
            echo ' '
            echo "-----------------------Alive------------------------"
            echo ' '
            echo "$MOUNT_POINT:"
            ls $MOUNT_POINT
    sleep $PERIOD
        fi
    done
    sleep $PERIOD
done
