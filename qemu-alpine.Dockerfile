# syntax=docker/dockerfile:1
FROM alpine:edge AS builder

ARG TARGETPLATFORM
# https://www.gnupg.org/ftp/gcrypt/gnutls/v${gnutls_version%.*}/gnutls-${gnutls_version}.tar.xz
ARG gnutls_version=3.8.5
ARG aria2_name
ARG aria2_version

# 3.20 版本需要在安装 c-ares-static
# gnutls : https
# libssh2 : sftp
# libnettle : bt(libnettle+libgmp)、checksum、json-rpc
# libxml2 : metalink、xml-rpc
# C-Ares : Async DNS
# zlib : gzip deflate in http
# libsqlite3 : firefox3/chromium cookie
# libuv : async i

RUN apk update && \
    apk add --no-cache \
        g++ \
        musl-dev  \
        jemalloc-dev \
        jemalloc-static \
        nettle-dev \
        nettle-static \
        gmp-dev \
        gmp-static \
        libssh2-dev \
        libssh2-static \
        c-ares-dev \
        libxml2-dev \
        libxml2-static \
        zlib-dev \
        zlib-static \
        sqlite-dev \
        sqlite-static \
        pkgconf-dev \
        alpine-sdk \
        sudo \
        libidn2-dev \
        libidn2-static \
        libkcapi-dev \
        libtasn1-dev \
        libunistring-dev \
        libunistring-static \
        linux-headers \
        p11-kit-dev \
        texinfo \
        zlib-dev \
        zlib-static \
        curl

RUN curl -O https://www.gnupg.org/ftp/gcrypt/gnutls/v${gnutls_version%.*}/gnutls-${gnutls_version}.tar.xz && \
    mkdir /tmp/gnutls && \
    tar -Jxvf gnutls-${gnutls_version}.tar.xz -C /tmp/gnutls --strip-components=1 && \
    cd /tmp/gnutls && \
	./configure \
		--prefix=/usr \
		--sysconfdir=/etc \
		--mandir=/usr/share/man \
		--infodir=/usr/share/info \
		--enable-ld-version-script  \
		--enable-cxx \
		--disable-rpath \
		--enable-libdane \
		--without-tpm \
		--enable-openssl-compatibility \
		--disable-silent-rules \
		--with-default-trust-store-file=/etc/ssl/certs/ca-certificates.crt \
		--disable-gtk-doc \
		--disable-doc \
		--enable-static && \
    make && \
    make install

# 解压 aria2并编译 aria2
RUN mkdir /tmp/aria2 &&  \
    curl -O https://github.com/aria2/aria2/releases/download/${aria2_version}/${aria2_name} && \
    tar -Jxvf ${aria2_name} -C /tmp/aria2 --strip-components=1 &&  \
    cd /tmp/aria2 && \
    CXXFLAGS="-std=c++11 -O2" ./configure  \
            ARIA2_STATIC=yes  \
            --with-gnutls \
            --without-openssl \
            --with-libssh2 \
            --with-libnettle \
            --without-libgcrypt \
            --with-libgmp  \
            --with-libxml2 \
            --without-libexpat  \
            --with-libcares  \
            --with-libz  \
            --with-sqlite3  \
            --with-libuv  \
            --without-wintls  \
            --without-appletls  \
            --disable-rpath  \
            --enable-static=yes  \
            --enable-shared=no  \
            --without-p11-kit \
            --disable-silent-rules  \
            --disable-nls \
            --with-ca-bundle='/etc/ssl/certs/ca-certificates.crt' \
            --with-jemalloc&&  \
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