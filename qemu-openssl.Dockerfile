# syntax=docker/dockerfile:1
FROM alpine:3.21.3 AS builder

ARG TARGETPLATFORM
ARG aria2_name
ARG aria2_version
ARG OPENSSL_VERSION=3.5.0

# 3.20 版本需要在安装 c-ares-static
RUN apk update && \
    apk add --no-cache \
        g++ \
        musl-dev  \
        pkgconf-dev \
        perl-dev \
        jemalloc-dev \
        jemalloc-static \
        libuv-dev \
        libuv-static \
        libssh2-dev \
        libssh2-static \
        c-ares-dev \
        libxml2-dev \
        libxml2-static \
        sqlite-dev \
        sqlite-static \
        zlib-dev \
        zlib-static \
        linux-headers

RUN wget https://github.com/openssl/openssl/releases/download/openssl-${OPENSSL_VERSION}/openssl-${OPENSSL_VERSION}.tar.gz && \
    target="" && \
    case "${TARGETPLATFORM}" in \
        "linux/arm64"*)   target="linux-aarch64" ;; \
        "linux/arm/v6")   target="linux-armv4" ;; \
        "linux/arm/v7")   target="linux-armv4" ;; \
        "linux/ppc64le")  target="linux-ppc64le" ;; \
        "linux/386")      target="linux-elf" ;; \
        "linux/amd64")    target="linux-x86_64";; \
        "linux/s390x")    target="linux64-s390x";; \
        "linux/riscv64")  target="linux64-riscv64";; \
        *)		echo "Unable to determine architecture from (ARCH=$TARGETPLATFORM)" ; exit 1 ;; \
    esac && \
    mkdir /tmp/openssl && \
    tar -axf openssl-${OPENSSL_VERSION}.tar.gz -C /tmp/openssl --strip-components=1 &&  \
    cd /tmp/openssl && \
    ./Configure $target --libdir=lib no-tests no-shared no-module enable-weak-ssl-ciphers &&  \
    make -j2 &&  \
    make install

# 解压 aria2并编译 aria2
RUN mkdir /tmp/aria2 &&  \
    wget https://github.com/aria2/aria2/releases/download/${aria2_version}/${aria2_name} && \
    tar -axvf ${aria2_name} -C /tmp/aria2 --strip-components=1 &&  \
    cd /tmp/aria2 && \
    CXXFLAGS="-std=c++11 -O2" ./configure  \
            ARIA2_STATIC=yes  \
            --without-gnutls \
            --with-openssl \
            --with-libssh2 \
            --without-libnettle \
            --without-libgcrypt \
            --without-libgmp  \
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
            --disable-silent-rules  \
            --disable-nls \
            --with-ca-bundle='/etc/ssl/certs/ca-certificates.crt' \
            --with-jemalloc &&  \
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