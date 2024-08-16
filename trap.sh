exit_script() {
    SIGNAL=$1
echo ' '
echo "-----------------Terminating-----------------"
echo ' '
    for MOUNT_POINT in /mnt/webdrive*; do
        if [ -d "$MOUNT_POINT" ]; then
            echo "Unmounting ${MOUNT_POINT}..."
            umount -f "$MOUNT_POINT"
        fi
    done
    rclone_pid=$(ps -o pid= -o comm= | grep rclone | sed -E 's/\s*(\d+)\s+.*/\1/g')
    if [ -n "$rclone_pid" ]; then
        echo "Forwarding $SIGNAL to $rclone_pid"
        while $(kill -$SIGNAL $rclone_pid 2> /dev/null); do
            sleep 1
        done
    fi
    trap - $SIGNAL # clear the trap
    exit $?
}

trap "exit_script INT" INT
trap "exit_script TERM" TERM
