exit_script() {
    SIGNAL=$1
    echo "Caught $SIGNAL! Unmounting ${DEST}..."
    fusermount -u ${DEST}
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

