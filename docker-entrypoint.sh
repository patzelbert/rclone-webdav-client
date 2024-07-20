#!/usr/bin/env sh
SUCCESS_FILE=/usr/local/bin/mounted
rm -f $SUCCESS_FILE
LOG_FILE="/var/log/rclone.log"
DEST=${WEBDRIVE_MOUNT:-/mnt/webdrive} 
MOUNT_POINT=/mnt/webdrive
CONFIG_FOLDER="/root/.config/rclone"
CONFIG_FILE="$CONFIG_FOLDER/rclone.conf"



# Check variables and defaults
if [ -z "${WEBDRIVE_URL}" ]; then
    echo "No URL specified!"
    exit 1
fi
if [ -z "${WEBDRIVE_USERNAME}" ]; then
    echo "No username specified, is this on purpose?"
    WEBDRIVE_USERNAME=""
fi
if [ -n "${WEBDRIVE_PASSWORD_FILE}" ]; then
    WEBDRIVE_PASSWORD=$(cat "${WEBDRIVE_PASSWORD_FILE}")
fi
if [ -z "${WEBDRIVE_PASSWORD}" ]; then
    echo "No password specified, is this on purpose?"
    WEBDRIVE_PASSWORD=""
fi
if [ -z "${CLEAR_TARGET}" ]; then
    echo "No clear target specified, defaulting to true"
    CLEAR_TARGET="true"
fi
if [ ! -d "$DEST" ]; then
    mkdir -p "$DEST"
fi
if [ ! -d "$CONFIG_FOLDER" ]; then
    mkdir -p "$CONFIG_FOLDER"
fi
if [ -n "$(env | grep "RCLONE_")" ]; then
    echo "" >> $CONFIG_FILE
    echo "[$DEST]" >> $CONFIG_FILE
    for VAR in $(env); do
        if [ -n "$(echo "$VAR" | grep -E '^RCLONE_')" ]; then
            OPT_NAME=$(echo "$VAR" | sed -r "s/RCLONE_([^=]*)=.*/\1/g" | tr '[:upper:]' '[:lower:]')
            VAR_FULL_NAME=$(echo "$VAR" | sed -r "s/([^=]*)=.*/\1/g")
            VAL=$(eval echo \$$VAR_FULL_NAME)
            echo "$OPT_NAME: $VAL" >> $CONFIG_FILE
        fi
    done
fi

# Rclone configuration
RCLONE_REMOTE_NAME="webdav_remote"  # Ensure this name is valid

# Clear existing rclone config if any
rclone config delete $RCLONE_REMOTE_NAME

# Create rclone configuration
rclone config create $RCLONE_REMOTE_NAME webdav url "$WEBDRIVE_URL" vendor other user "$WEBDRIVE_USERNAME" pass "$WEBDRIVE_PASSWORD" --log-file=$LOG_FILE --config $CONFIG_FILE

unset WEBDRIVE_PASSWORD

rm -f $LOG_FILE
touch $LOG_FILE
# Create destination directory if it does not exist.
if [ ! -d "$DEST" ]; then
    mkdir -p "$DEST"
fi

# Deal with ownership
if ! id -u webdrive >/dev/null 2>&1; then
    adduser -D -u "$UID" webdrive
else
    usermod -aG webdrive $UID
fi
chown webdrive:users -R "$DEST"
chmod 755 -R "$DEST"

# Mount with rclone

rclone mount "$RCLONE_REMOTE_NAME:" "$DEST" --vfs-cache-mode full --uid "$UID" --gid "$GID" --dir-perms 755 --file-perms 755 --log-file=$LOG_FILE --daemon --allow-non-empty --allow-other --config $CONFIG_FILE

sleep 5

# Check if the mount was successful
if mountpoint -q "$DEST"; then
    echo "Mounted $WEBDRIVE_URL onto $DEST"
    echo "Sync $DEST"
    sync "$DEST"
    # Notify other containers by touching a file or using another method
    touch $SUCCESS_FILE
    # Output the content of the log file
    cat $LOG_FILE
    exec "$@"
else
    echo "Mounting $WEBDRIVE_URL onto $DEST failed!"
    # Output the content of the log file before exiting
    cat $LOG_FILE
    exit 1
fi