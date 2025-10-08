# syntax=docker/dockerfile:1
FROM debian:trixie-20241016 AS builder

ARG PACKAGE="libuv1-dev perl libgpg-error-dev libsqlite3-dev zlib1g-dev libexpat1-dev libssh2-1-dev libcppunit-dev make pkgconf build-essential ca-certificates-bundle"
ARG TARGETPLATFORM

RUN apt-get update && \
    apt-get install -y ${PACKAGE}

# 复制全部软件包到 /tmp
COPY package/* /tmp

# 编译 c-ares
#RUN mkdir /tmp/c-ares && \
#    tar xf /tmp/c-ares-1.34.2.tar.gz -C /tmp/c-ares --strip-components=1 && \
#    cd /tmp/c-ares && \
#    ./configure --disable-shared --enable-static && \
#    make -j2 && \
#    make install

RUN mkdir /etc/openssl_host && \
    if [ ${TARGETPLATFORM} = 'linux/amd64' ]; then \
        echo "linux-x86_64" >> /tmp/openssl_host; \
    elif [ ${TARGETPLATFORM} = 'linux/386' ]; then \
        echo "linux-x86" >> /tmp/openssl_host; \
    elif [ ${TARGETPLATFORM} = 'linux/arm64' ]; then \
        echo "linux-aarch64" >> /tmp/openssl_host; \
    elif [ ${TARGETPLATFORM} = 'linux/arm/v7' ]; then \
        echo "linux-armv4" >> /tmp/openssl_host; \
    elif [ ${TARGETPLATFORM} = 'linux/riscv64' ]; then \
        echo "linux64-riscv64" >> /tmp/openssl_host; \
    elif [ ${TARGETPLATFORM} = 'linux/ppc64le' ]; then \
        echo "linux-ppc64le" >> /tmp/openssl_host; \
    elif [ ${TARGETPLATFORM} = 'linux64/s390x' ]; then \
        echo "linux64-s390x" >> /tmp/openssl_host; \
    fi

# 编译 openssl
RUN mkdir /tmp/openssl &&  \
    tar xf /tmp/openssl-3.4.0.tar.gz -C /tmp/openssl --strip-components=1 &&  \
    cd /tmp/openssl &&  \
    sed -i '/^default = default_sect/a legacy = legacy_sect' apps/openssl.cnf && \
    sed -i '/^providers = provider_sect/a [legacy_sect]\nactivate = 1' apps/openssl.cnf && \
    sed -i 's/^# activate = 1/activate = 1/' apps/openssl.cnf && \
    export OPENSSL_HOST=$(cat /tmp/openssl_host) && \
    ./Configure $OPENSSL_HOST --libdir=lib no-tests no-shared no-module enable-weak-ssl-ciphers &&  \
    make -j2 &&  \
    make install

# 解压 aria2并编译 aria2
RUN mkdir /tmp/aria2 &&  \
    tar xf /tmp/aria2-1.37.0.tar.gz -C /tmp/aria2 --strip-components=1 &&  \
    cd /tmp/aria2 && \
    ./configure  \
            ARIA2_STATIC=yes  \
            --with-libuv \
            --disable-rpath  \
            --enable-static=yes  \
            --enable-shared=no  \
            --with-ca-bundle='/etc/ssl/certs/ca-certificates.crt' || (cat config.log && false)  &&  \
    make &&  \
    strip src/aria2c


FROM alpine:3.20.3

LABEL author=roukaixin

EXPOSE 6800/tcp 6881-6999/udp 6881-6999/tcp

# supercronic 定时任务
RUN apk add --no-cache  \
    supercronic \
    s6-overlay \
    && rm -rf /var/cache/apk/*

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