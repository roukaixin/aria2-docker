FROM alpine AS builder

ARG MAKE_PACKAGE="g++ gcc make pkgconfig"
ARG ARIA2_TEST="cppunit"
ARG BASE_PACKAGE="openssl-dev libssh2-dev expat-dev zlib-dev c-ares-dev sqlite-dev"
COPY aria2-1.37.0.tar.gz /tmp
RUN mkdir /tmp/aria2 && tar xvf /tmp/aria2-1.37.0.tar.gz -C /tmp/aria2 --strip-components=1
RUN sed -i 's/dl-cdn.alpinelinux.org/mirrors.ustc.edu.cn/g' /etc/apk/repositories && \
    apk update &&  \
    apk add --no-cache ${MAKE_PACKAGE} ${ARIA2_TEST} ${BASE_PACKAGE}

RUN cd /tmp/aria2 && \
    ./configure ARIA2_STATIC=yes --disable-rpath --enable-static=yes --enable-shared=no --with-ca-bundle='/etc/ssl/certs/ca-certificates.crt'  &&  \
    make &&  \
    strip src/aria2c




FROM alpine

COPY s6-overlay-noarch.tar.xz /tmp
RUN tar -p -C / -Jxpf /tmp/s6-overlay-noarch.tar.xz
COPY s6-overlay-x86_64.tar.xz /tmp
RUN tar -p -C / -Jxpf /tmp/s6-overlay-x86_64.tar.xz
RUN rm -rf /tmp

WORKDIR /aria2
COPY --from=builder /tmp/aria2/src/aria2c bin/
COPY /rootfs/etc/ /etc/
RUN mkdir -p config .aria2 && touch .aria2/aria2.session && cp /etc/aria2/config/aria2.conf config/
RUN addgroup -g 1000 aria2 && adduser -D -G aria2 -u 1000 -h /aria2 aria2  && chown -R aria2:aria2 /aria2

USER aria2:aria2

ENV PATH /aria2/bin:$PATH

ENTRYPOINT ["/init"]
CMD []