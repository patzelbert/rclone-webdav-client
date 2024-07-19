# Dockerised RCLONE WebDAV Client

This Docker [image] and associated [project] facilitate
mounting of remote WebDAV resources into containers. Mounting is implemented
using [rclone] and the image makes it possible to set all supported rclone
[configuration] options for the share. The image basically implements a docker
[volume] on the cheap: Used with the proper creation options (see below) , you
should be able to bind-mount back the remote bucket onto a host directory. This
directory will make the content of the bucket available to processes, but also
all other containers on the host. The image automatically unmounts the remote
bucket on container termination.

  [image]: https://hub.docker.com/r/patzelbert/rclone-webdav-client
  [project]: https://github.com/patzelbert/rclone-webdav-client
  [rclone]: https://github.com/search?q=rclone&type=repositories
  [configuration]: https://rclone.org/
  [volume]: https://docs.docker.com/storage/

## Example

Provided the existence of a directory called `/mnt/tmp` on the host, the
following command would mount a remote WebDAV resource, ensure that
authentication details are never requested from the command-line and bind-mount
the remote resource onto the host's `/mnt/tmp` in a way that makes the remote
files accessible to processes and/or other containers running on the same host.

```Shell
docker run -it --rm \
    --device /dev/fuse \
    --cap-add SYS_ADMIN \
    --security-opt "apparmor=unconfined" \
    --env "WEBDRIVE_USERNAME=<YourUserName>" \
    --env "WEBDRIVE_PASSWORD=<SuperSecretPassword>" \
    --env "WEBDRIVE_URL=https://dav.box.com/dav" \
    --env "RCLONE_CACHE_INFO_AGE=1h" \
    -v /mnt/tmp:/mnt/webdrive:rshared \
    patzelbert/rclone-webdav-client
```

The `--device`, `--cap-add` and `--security-opt` options and their values are to
make sure that the container will be able to make available the WebDAV resource
using FUSE. `rshared` is what ensures that bind mounting makes the files and
directories available back to the host and recursively to other containers.

## Container Options

A series of environment variables, most led by `WEBDRIVE_` can be used to
parametrise the container:

* `WEBDRIVE_URL` is the URL at which to find the WebDAV resource.
* `WEBDRIVE_USERNAME` is the user to use for accessing the resource.
* `WEBDRIVE_PASSWORD` is the password for that user.
* `WEBDRIVE_PASSWORD_FILE` points instead to a file that will contain the
  password for the user. When this is present, the password will be taken from
  the file instead of from the `WEBDRIVE_PASSWORD` variable. If that variable
  existed, it will be disregarded. This makes it easy to pass passwords using 
  Docker [secrets].
* `WEBDRIVE_MOUNT` is the location within the container where to mount the
  WebDAV resource. This defaults to `/mnt/webdrive` and is not really meant to
  be changed.
* `UID` is the user ID for the owner of the share inside the container.
* `GID` is the user ID for the owner of the share inside the container.

  [secrets]: https://docs.docker.com/engine/swarm/secrets/

## davFS Options

All [configuration] options recognised by rclone can be given for that particular
share. Environment variables should be created out of the name of the
configuration option for this to work. Any existing option should be translated
to uppercase and led by the keyword `RCLONE_` to be recognised. So to set the
rclone option called `cache-info-age` to `1m`, you would set the environment variable
`RCLONE_CACHE_INFO_AGE` to `1m`.

## Commands

By default, containers based on this image will keep listing the content of the
mounted directory at regular intervals. This is implemented by the
[command](./ls.sh) that it is designed to execute once the remote WebDAV
resource has been mounted. If you did not wish this behaviour, pass `empty.sh`
as the command instead.

Note that both of these commands ensure that the remote WebDAV resource is
unmounted from the mountpoint at termination, so you should really pick one or
the other to allow for proper operation. If the mountpoint was not unmounted,
your mount system will be unstable as it will contain an unknown entry.

Automatic unmounting is achieved through a combination of a `trap` in the
command being executed and [tini]. [tini] is made available directly in this
image to make it possible to run in [Swarm] environments.

special thanks to [efrecon].

  [tini]: https://github.com/krallin/tini
  [Swarm]: https://docs.docker.com/engine/swarm/
  [efrecon]: https://github.com/efrecon

  
## Docker Compose
```Shell
	services:
	  webdav-client:
		image: patzelbert/rclone-webdav-client:latest
		container_name: webdav-client
		restart: always
		privileged: true
		user: root
		environment:
		  DEBUG: LOG_DEBUG
		  WEBDRIVE_USERNAME: $WEBDAV_USERNAME
		  WEBDRIVE_PASSWORD: $WEBDAV_PASSWORD
		  WEBDRIVE_URL: $WEBDAV_URL
		  RCLONE_CACHE_CHUNK_SIZE: 5M
		  RCLONE_CACHE_INFO_AGE: 1h
		  RCLONE_CACHE_CHUNK_TOTAL_SIZE: 10G
		  RCLONE_CACHE_DB_PATH: /var/cache/webdav
		  RCLONE_CACHE_CHUNK_CLEAN_INTERVAL: 1m
		  RCLONE_CACHE_READ_RETRIES: 3 
		  UID: 1000
		  GID: 1000
		networks:
		  - webdav-nw
		volumes:
		  - ./data:/mnt/webdrive:rshared
		  - ./cache:/var/cache/webdav:rw
		healthcheck:
		  test: ["CMD-SHELL", "test -f /usr/local/bin/mounted  && sleep 1 || exit 1"]
		  interval: 20s
		  timeout: 15s
		  retries: 10
		  start_period: 10s     
	networks:
	  webdav-nw:
		internal: false
		driver: bridge
		driver_opts:
		  com.docker.network.bridge.name: webdav-${PROJECT_NAME}
		  com.docker.network.bridge.enable_icc: 1

```

