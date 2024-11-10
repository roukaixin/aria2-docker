# syntax=docker/dockerfile:1
FROM debian:trixie-20241016 AS builder

ARG PACKAGE="libuv1-dev perl libgpg-error-dev libsqlite3-dev zlib1g-dev libexpat1-dev libssh2-1-dev libcppunit-dev make pkgconf build-essential"
ARG TARGETPLATFORM

RUN apt-get update && \
    apt-get install -y ${PACKAGE}

# 复制全部软件包到 /tmp
COPY package/* /tmp

# 编译 c-ares
RUN mkdir /tmp/c-ares && \
    tar xf /tmp/c-ares-1.34.2.tar.gz -C /tmp/c-ares --strip-components=1 && \
    cd /tmp/c-ares && \
    ./configure --disable-shared --enable-static && \
    make -j2 && \
    make install

ENV OPENSSL_HOST=''
RUN if [ ${TARGETPLATFORM} = 'linux/arm/v7' ]; then \
        export OPENSSL_HOST='linux-armv4'; \
    fi && \
    echo '变量值为 $OPENSSL_HOST' && \
    echo 'OPENSSL_HOST=$OPENSSL_HOST' >> /etc/environment

# 编译 openssl
RUN . /etc/environment && \
    mkdir /tmp/openssl &&  \
    tar xf /tmp/openssl-3.4.0.tar.gz -C /tmp/openssl --strip-components=1 &&  \
    cd /tmp/openssl &&  \
    sed -i '/^default = default_sect/a legacy = legacy_sect' apps/openssl.cnf && \
    sed -i '/^providers = provider_sect/a [legacy_sect]\nactivate = 1' apps/openssl.cnf && \
    sed -i 's/^# activate = 1/activate = 1/' apps/openssl.cnf && \
    ./Configure ${OPENSSL_HOST} --libdir=lib no-tests -no-shared no-module enable-weak-ssl-ciphers &&  \
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

ARG TARGETPLATFORM
ARG S6_OVERLAY_VERSION=3.2.0.2

ADD https://github.com/just-containers/s6-overlay/releases/download/v${S6_OVERLAY_VERSION}/s6-overlay-noarch.tar.xz /tmp
RUN tar -p -C / -Jxpf /tmp/s6-overlay-noarch.tar.xz

ENV HOST_MACHINE=''
RUN if [ ${TARGETPLATFORM} = 'linux/amd64' ]; then \
        wget -P /tmp https://github.com/just-containers/s6-overlay/releases/download/v${S6_OVERLAY_VERSION}/s6-overlay-x86_64.tar.xz; \
        tar -p -C / -Jxpf /tmp/s6-overlay-x86_64.tar.xz; \
    elif [ ${TARGETPLATFORM} = 'linux/arm64/v8' ]; then \
        wget -P /tmp https://github.com/just-containers/s6-overlay/releases/download/v${S6_OVERLAY_VERSION}/s6-overlay-aarch64.tar.xz; \
        tar -p -C / -Jxpf /tmp/s6-overlay-aarch64.tar.xz; \
    elif [ ${TARGETPLATFORM} = 'linux/arm/v7' ]; then \
        wget -P /tmp https://github.com/just-containers/s6-overlay/releases/download/v${S6_OVERLAY_VERSION}/s6-overlay-armhf.tar.xz; \
        tar -p -C / -Jxpf /tmp/s6-overlay-armhf.tar.xz; \
    elif [ ${TARGETPLATFORM} = 'linux/386' ]; then \
        wget -P /tmp https://github.com/just-containers/s6-overlay/releases/download/v${S6_OVERLAY_VERSION}/s6-overlay-i686.tar.xz; \
        tar -p -C / -Jxpf /tmp/s6-overlay-i686.tar.xz; \
    elif [ ${TARGETPLATFORM} = 'linux/riscv64' ]; then \
        wget -P /tmp https://github.com/just-containers/s6-overlay/releases/download/v${S6_OVERLAY_VERSION}/s6-overlay-riscv64.tar.xz; \
        tar -p -C / -Jxpf /tmp/s6-overlay-riscv64.tar.xz; \
    elif [ ${TARGETPLATFORM} = 'linux/ppc64le' ]; then \
        wget -P /tmp https://github.com/just-containers/s6-overlay/releases/download/v${S6_OVERLAY_VERSION}/s6-overlay-powerpc64le.tar.xz; \
        tar -p -C / -Jxpf /tmp/s6-overlay-powerpc64le.tar.xz; \
    elif [ ${TARGETPLATFORM} = 'linux/s390x' ]; then \
        wget -P /tmp https://github.com/just-containers/s6-overlay/releases/download/v${S6_OVERLAY_VERSION}/s6-overlay-s390x.tar.xz; \
        tar -p -C / -Jxpf /tmp/s6-overlay-s390x.tar.xz; \
    fi
RUN rm -rf /tmp

WORKDIR /aria2
COPY --from=builder /tmp/aria2/src/aria2c bin/
COPY /rootfs/etc/ /etc/
RUN mkdir -p config .aria2 download &&  \
    touch .aria2/aria2.session &&  \
    cp /etc/aria2/config/aria2.conf config/ && \
    find /etc/s6-overlay/scripts -type f -exec chmod +x {} \;
RUN addgroup -g 1000 aria2 && adduser -D -G aria2 -u 1000 -h /aria2 aria2  && chown -R aria2:aria2 /aria2

USER aria2:aria2

EXPOSE 6800 6881-6999/udp 6881-6999

ENV PATH=/aria2/bin:$PATH S6_BEHAVIOUR_IF_STAGE2_FAILS=2

ENTRYPOINT [ "/init" ]
CMD [ "aria2c", "--conf-path=/aria2/config/aria2.conf" ]