#!/usr/bin/env sh
# Signal handler: cleanly detach every rclone mount on container stop.
#
# Uses LAZY unmount (fusermount -uz / umount -l) rather than `umount -f`.
# Because the mounts are bind-propagated to the host (rshared), a forced
# unmount that hits "Resource busy" can leave a stale "Transport endpoint is
# not connected" mount on the host, which then blocks the container from
# starting again. Lazy unmount detaches immediately and lets the propagation
# tear down cleanly.
exit_script() {
    SIGNAL=$1
    echo ' '
    echo "-----------------Terminating-----------------"
    echo ' '
    for MOUNT_POINT in /mnt/webdrive*; do
        if [ -d "$MOUNT_POINT" ]; then
            echo "Unmounting ${MOUNT_POINT}..."
            fusermount3 -uz "$MOUNT_POINT" 2>/dev/null \
                || fusermount -uz "$MOUNT_POINT" 2>/dev/null
            umount -l "$MOUNT_POINT" 2>/dev/null
        fi
    done
    rclone_pid=$(ps -o pid= -o comm= | grep rclone | sed -E 's/\s*([0-9]+)\s+.*/\1/g')
    if [ -n "$rclone_pid" ]; then
        echo "Forwarding $SIGNAL to $rclone_pid"
        for p in $rclone_pid; do
            kill -"$SIGNAL" "$p" 2>/dev/null
        done
    fi
    trap - "$SIGNAL" # clear the trap
    exit 0
}

trap "exit_script INT" INT
trap "exit_script TERM" TERM
