# A newer build for the update test: the sealed OS image OS with another
# IMAGE_VERSION, which is all that the test tells builds apart by. Made in
# minutes rather than by building the image again; sealing makes it boot as
# built (make update-builds).
ARG OS
FROM ${OS}
ARG IMAGE_VERSION
RUN test -n "$IMAGE_VERSION" && \
    sed -i "s/^IMAGE_VERSION=.*/IMAGE_VERSION=$IMAGE_VERSION/" /usr/lib/os-release && \
    grep -qx "IMAGE_VERSION=$IMAGE_VERSION" /usr/lib/os-release
LABEL org.opencontainers.image.version="$IMAGE_VERSION"
