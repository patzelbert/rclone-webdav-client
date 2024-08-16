#!/usr/bin/env sh
echo "-----------------RClone Webdav Client-----------------"
echo ' '
touch /var/log/rclone.log

SUCCESS_FILE=/usr/local/bin/mounted
rm -f $SUCCESS_FILE
LOG_FILE="/var/log/rclone.log"
CONFIG_FOLDER="/root/.config/rclone"
CONFIG_FILE="$CONFIG_FOLDER/rclone.conf"

# Check if directories exist, if not create them
create_directory() {
    DIRECTORY=$1
    if [ ! -d "$DIRECTORY" ]; then
        echo "Creating $DIRECTORY"
        mkdir -p "$DIRECTORY"
    fi
}

# Function to create rclone configuration and mount for each URL
mount_webdav() {
    MOUNT_POINT=$1
    URL=$2
    USERNAME=$3
    PASSWORD=$4

    RCLONE_REMOTE_NAME="webdav_remote_$(echo $MOUNT_POINT | tr '/' '_')"  # Unique name per mount point

    # Clear existing rclone config if any
    rclone config delete $RCLONE_REMOTE_NAME

    # Create rclone configuration
    rclone config create $RCLONE_REMOTE_NAME webdav url "$URL" vendor other user "$USERNAME" pass "$PASSWORD" --log-file=$LOG_FILE --config $CONFIG_FILE

    # Mount with rclone
    rclone mount "$RCLONE_REMOTE_NAME:" "$MOUNT_POINT" --vfs-cache-mode full --uid "$UID" --gid "$GID" --dir-perms 755 --file-perms 755 --log-file=$LOG_FILE --daemon --allow-non-empty --allow-other --config $CONFIG_FILE

    sleep 5

    # Check if the mount was successful
    if mountpoint -q "$MOUNT_POINT"; then
        echo "Mounted $URL onto $MOUNT_POINT"
        echo "Sync $MOUNT_POINT"
        sync "$MOUNT_POINT"
    else
        echo "Mounting $URL onto $MOUNT_POINT failed!"
        cat $LOG_FILE
        exit 1
    fi
}

# Ensure the configuration folder exists
create_directory "$CONFIG_FOLDER"

# Read in array of URLs
# Split the string by commas if a comma is present
URLS=${WEBDRIVE_URLS//,/ }

# Username and password are the same for all URLs
USERNAME="$WEBDRIVE_USERNAME"
PASSWORD="$WEBDRIVE_PASSWORD"



index=1
for url in $URLS; do

    MOUNT_POINT="/mnt/webdrive$index"
    echo ' '
    echo "-----------------------Mounting-----------------------"
    echo ' '
    echo creating "$MOUNT_POINT"
    create_directory "$MOUNT_POINT"
    echo mounting "$MOUNT_POINT"
    mount_webdav "$MOUNT_POINT" "$url" "$USERNAME" "$PASSWORD"
    index=$((index + 1)) 

done

# Notify other containers by touching a file or using another method
touch $SUCCESS_FILE

# Output the content of the log file
cat $LOG_FILE

exec "$@"
