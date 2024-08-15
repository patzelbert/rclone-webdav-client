#! /usr/bin/env sh

PERIOD=${1:-60}
. trap.sh
echo ' '
echo "-----------------------Running-----------------------"
echo ' '
while true; do
    for MOUNT_POINT in /mnt/webdrive*; do
        if [ -d "$MOUNT_POINT" ]; then
            echo "$MOUNT_POINT is still mounted..."
        fi
    done
    sleep $PERIOD
done
