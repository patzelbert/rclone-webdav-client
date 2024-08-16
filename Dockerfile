FROM alpine:latest

# Metadata
LABEL MAINTAINER=p.heydorn@gmail.com
LABEL org.opencontainers.image.title="patzelbert/rclone-webdav-client"
LABEL org.opencontainers.image.description="Mount WebDAV shares from within a container and expose them to host/containers"
LABEL org.opencontainers.image.authors="Patrick Heydorn" 
LABEL org.opencontainers.image.url="https://github.com/patzelbert/rclone-webdav-client"
LABEL org.opencontainers.image.documentation="https://github.com/patzelbert/rclone-webdav-client/README.md"
LABEL org.opencontainers.image.source="https://github.com/patzelbert/rclone-webdav-client/Dockerfile"

# Specify URL, username and password to communicate with the remote webdav
# resource. When using _FILE, the password will be read from that file itself,
# which helps passing further passwords using Docker secrets.
ENV WEBDRIVE_URL=
ENV WEBDRIVE_USERNAME=
ENV WEBDRIVE_PASSWORD=
ENV WEBDRIVE_PASSWORD_FILE=
ENV RCLONE_CACHE_CHUNK_SIZE=5M
ENV RCLONE_CACHE_INFO_AGE=1h
ENV RCLONE_CACHE_CHUNK_TOTAL_SIZE=10G
ENV RCLONE_CACHE_DB_PATH=/path/to/cache/db
ENV RCLONE_CACHE_CHUNK_CLEAN_INTERVAL=1m
ENV RCLONE_CACHE_READ_RETRIES=3
ENV RCLONE_LOG_LEVEL=WARNING
ENV RCLONE_LOG_FORMAT=LOG_DEBUG
# User ID of share owner
ENV UID=0
ENV GID=0 

RUN apk --no-cache add ca-certificates fuse3 tini rclone
RUN apk upgrade --available

COPY *.sh /usr/local/bin/
RUN chown $UID:$GID /usr/local/bin/*.sh
RUN chmod +x /usr/local/bin/*.sh


ENTRYPOINT [ "tini", "-g", "--", "/usr/local/bin/docker-entrypoint.sh" ]
CMD [ "ls.sh" ]
