# syntax=docker/dockerfile:1
FROM alpine:3.20.3 AS builder

ARG TARGETPLATFORM
ARG TARGETARCH
ARG package_root=/root/packages/tmp
ARG gnutls_version=3.8.5

# 3.20 版本需要在安装 c-ares-static
# gnutls : https
# libssh2 : sftp
# libnettle : bt(libnettle+libgmp)、checksum、json-rpc
# libxml2 : metalink、xml-rpc
# C-Ares : Async DNS
# zlib : gzip deflate in http
# libsqlite3 : firefox3/chromium cookie
# libuv : async io
RUN apk update && \
    apk add --no-cache \
    g++ \
    musl-dev  \
    make  \
    pkgconf \
    libssh2-dev \
    libssh2-static  \
    nettle-dev  \
    nettle-static \
    gmp-dev \
    libxml2-dev \
    libxml2-static  \
    c-ares-dev  \
    c-ares-static \
    zlib-dev  \
    zlib-static \
    sqlite-dev  \
    sqlite-static \
    libuv-dev \
    libuv-static  \
    alpine-sdk \
    sudo  \
    curl \
    libtasn1-dev \
    libunistring-dev

# 复制全部软件包到 /tmp
COPY package/ /tmp

RUN abuild-keygen -a -i -n

RUN curl -O https://www.gnupg.org/ftp/gcrypt/gnutls/v${gnutls_version%.*}/gnutls-${gnutls_version}.tar.xz && \
    mkdir /tmp/gnutls && \
    tar -Jxvf gnutls-${gnutls_version}.tar.xz -C /tmp/gnutls --strip-components=1 && \
    cd /tmp/gnutls && \
    ./configure \
    		--host=$(uname -m) \
    		--prefix=/usr \
    		--sysconfdir=/etc \
    		--mandir=/usr/share/man \
    		--infodir=/usr/share/info \
    		--enable-ktls \
    		--disable-openssl-compatibility \
    		--disable-rpath \
    		--disable-valgrind-tests    \
            --without-p11-kit \
    		--enable-static && \
    make && \
    make install


# 解压 aria2并编译 aria2
RUN mkdir /tmp/aria2 &&  \
    tar xf /tmp/aria2-1.37.0.tar.gz -C /tmp/aria2 --strip-components=1 &&  \
    cd /tmp/aria2 && \
    CXXFLAGS="-std=c++11 -O2" ./configure  \
            ARIA2_STATIC=yes  \
            --with-gnutls \
            --with-libssh2 \
            --with-libnettle \
            --with-libgmp  \
            --with-libxml2 \
            --with-libcares  \
            --with-libz  \
            --with-sqlite3  \
            --with-libuv  \
            --disable-rpath  \
            --enable-static=yes  \
            --enable-shared=no  \
            --without-p11-kit \
            --disable-silent-rules  \
            --disable-nls \
            --with-ca-bundle='/etc/ssl/certs/ca-certificates.crt' &&  \
    make &&  \
    strip src/aria2c


FROM alpine:3.21.3

LABEL author=roukaixin

EXPOSE 6800/tcp 6881-6999/udp 6881-6999/tcp

# supercronic 定时任务
RUN apk add --no-cache  \
    supercronic \
    s6-overlay \
    && rm -rf /var/cache/apk/* /tmp/*

RUN addgroup -S -g 1000 aria2 &&  \
    adduser -D -G aria2 -u 1000 -h /aria2 aria2

COPY --from=builder /tmp/aria2/src/aria2c /aria2/bin/
COPY /rootfs/etc/ /etc/

ENV PATH=/aria2/bin:$PATH \
    HOME=/aria2 \
    S6_BEHAVIOUR_IF_STAGE2_FAILS=2 \
    BT_TRACKER_CRON_ENABLE=true \
    CONF_PATH=false

RUN find /etc/s6-overlay/scripts -type f -exec chmod +x {} \;

VOLUME ["/aria2/download", "/aria2/.aria2", "/aria2/config"]

WORKDIR /aria2

ENTRYPOINT [ "/init" ]