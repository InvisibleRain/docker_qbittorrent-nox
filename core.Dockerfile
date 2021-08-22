FROM alpine:3.14 AS qbittorrent-build

ARG QBITTORRENT_VERSION=4.3.7
ARG QBITTORRENT_SHA_512=53a7bd7b21f0439d9407e8c823086004c1f01d856903e22a7f5a5b97c5ef39f807d6168158af1eb008fab21c78f7c81b8d8e142a3f3f74d5232653f43559cafd

ARG LIBTORRENT_VERSION=2.0.4
ARG LIBTORRENT_SHA_512=66ce3c3369b1d2a83654727c23022d38b070b8bc3ad83b1001e2cfad945acbaa4d61990094bc758886967cd305ca2213b60b1b0523b5106c42d4701d8cff8db1

ADD https://github.com/qbittorrent/qBittorrent/archive/release-${QBITTORRENT_VERSION}.tar.gz \
    /tmp/qbittorrent.tar.gz

ADD https://github.com/arvidn/libtorrent/releases/download/v${LIBTORRENT_VERSION}/libtorrent-rasterbar-${LIBTORRENT_VERSION}.tar.gz \
    /tmp/libtorrent.tar.gz

RUN cd /tmp \
 && echo "${LIBTORRENT_SHA_512}  libtorrent.tar.gz" > libtorrent.tar.gz.sha512 \
 && sha512sum -c libtorrent.tar.gz.sha512 \
 && tar xvzf libtorrent.tar.gz \
 && mv libtorrent-rasterbar-${LIBTORRENT_VERSION} libtorrent \
 && echo "${QBITTORRENT_SHA_512}  qbittorrent.tar.gz" > qbittorrent.tar.gz.sha512 \
 && sha512sum -c qbittorrent.tar.gz.sha512 \
 && tar xvzf qbittorrent.tar.gz \
 && mv qBittorrent-release-${QBITTORRENT_VERSION} qbittorrent \
 && apk add --no-cache --update \
            autoconf \
            automake \
            boost-dev \
            build-base \
            cmake \
            ninja \
            openssl-dev \
            python3-dev \
            qt5-qtbase-dev \
            qt5-qttools-dev \
# See: https://www.rasterbar.com/products/libtorrent/building.html
 && cd /tmp/libtorrent \
 && mkdir build \
 && cd build \
 && cmake -DCMAKE_BUILD_TYPE=Release -DCMAKE_CXX_STANDARD=14 -G Ninja .. \
 && ninja \
 && ninja install \
# See: https://git.alpinelinux.org/aports/tree/testing/qbittorrent-nox/APKBUILD
 && cd /tmp/qbittorrent \
 && ./configure --disable-gui \
                --disable-qt-dbus \
 && make


FROM alpine:3.14 AS ipfilter-build

RUN apk add --no-cache --update \
    bash \
    coreutils \
    git \
 && git clone https://github.com/fonic/ipfilter.git /ipfilter \
 && cd /ipfilter/sources \
 && ./ipfilter.sh


FROM padhihomelab/alpine-base:3.14.1_0.19.0_0.2


COPY --from=qbittorrent-build \
     /usr/local/lib/libtorrent-rasterbar.so.2.0 \
     /usr/local/lib/
COPY --from=qbittorrent-build \
     /tmp/qbittorrent/src/qbittorrent-nox \
     /usr/bin
COPY --from=ipfilter-build \
     /ipfilter/sources/ipfilter.p2p /

COPY qBittorrent.conf       /
COPY qbittorrent.sh         /usr/local/bin/qbittorrent
COPY 10-setup-volume.sh     /etc/docker-entrypoint.d/


RUN chmod +x /usr/bin/qbittorrent-nox \
             /usr/local/bin/qbittorrent \
             /etc/docker-entrypoint.d/10-setup-volume.sh \
 && apk add --no-cache --update \
            libcrypto1.1 \
            libgcc \
            libstdc++ \
            qt5-qtbase \
            zlib


EXPOSE 8080
VOLUME [ "/config", "/data", "/torrents/complete", "/torrents/incomplete" ]


CMD [ "qbittorrent" ]


HEALTHCHECK --start-period=10s --interval=30s --timeout=5s --retries=3 \
        CMD ["wget", "-qSO", "/dev/null",  "http://localhost:8080/"]
