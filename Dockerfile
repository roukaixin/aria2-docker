FROM debian:bookworm-slim AS builder

ARG MAKE_PACKAGE="build-essential make pkg-config"
ARG ARIA2_TEST="libcppunit-dev"
ARG BASE_PACKAGE="libssh2-1-dev libexpat1-dev zlib1g-dev libc-ares-dev libsqlite3-dev libgpg-error-dev perl libuv1-dev"
COPY aria2-1.37.0.tar.gz /tmp
RUN mkdir /tmp/aria2 &&  \
    tar xvf /tmp/aria2-1.37.0.tar.gz -C /tmp/aria2 --strip-components=1
RUN sed -i 's/deb.debian.org/mirrors.ustc.edu.cn/g' /etc/apt/sources.list.d/debian.sources && \
    apt update &&  \
    apt install -y ${MAKE_PACKAGE} ${ARIA2_TEST} ${BASE_PACKAGE}


COPY openssl-3.4.0.tar.gz /tmp
RUN mkdir /tmp/openssl &&  \
    tar xvf /tmp/openssl-3.4.0.tar.gz -C /tmp/openssl --strip-components=1 &&  \
    cd /tmp/openssl &&  \
    sed -i '/^default = default_sect/a legacy = legacy_sect' apps/openssl.cnf && \
    sed -i '/^providers = provider_sect/a [legacy_sect]\nactivate = 1' apps/openssl.cnf && \
    sed -i 's/^# activate = 1/activate = 1/' apps/openssl.cnf && \
    ./Configure --libdir=lib no-tests -no-shared no-module  enable-weak-ssl-ciphers &&  \
    make &&  \
    make install


# 编译 aria2
RUN cd /tmp/aria2 && \
    ./configure  \
            ARIA2_STATIC=yes  \
            LIBS='-luv_a -lpthread -ldl -lrt ' \
            --disable-rpath  \
            --enable-static=yes  \
            --enable-shared=no  \
            --with-ca-bundle='/etc/ssl/certs/ca-certificates.crt'  &&  \
    make &&  \
    strip src/aria2c




FROM alpine:3.20.3

COPY s6-overlay-noarch.tar.xz /tmp
RUN tar -p -C / -Jxpf /tmp/s6-overlay-noarch.tar.xz
COPY s6-overlay-x86_64.tar.xz /tmp
RUN tar -p -C / -Jxpf /tmp/s6-overlay-x86_64.tar.xz
RUN rm -rf /tmp

WORKDIR /aria2
COPY --from=builder /tmp/aria2/src/aria2c bin/
COPY /rootfs/etc/ /etc/
RUN mkdir -p config .aria2 &&  \
    touch .aria2/aria2.session &&  \
    cp /etc/aria2/config/aria2.conf config/ && \
    find /etc/s6-overlay/scripts -type f -exec chmod +x {} \;
RUN addgroup -g 1000 aria2 && adduser -D -G aria2 -u 1000 -h /aria2 aria2  && chown -R aria2:aria2 /aria2

USER aria2:aria2

ENV PATH /aria2/bin:$PATH

ENTRYPOINT [ "/init" ]
CMD [ "aria2c", "--conf-path=/aria2/config/aria2.conf" ]