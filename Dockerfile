FROM alpine:3.5

LABEL maintainer "Lukas Prettenthaler <lukas@noenv.com>"
LABEL version "1.2.2"
LABEL description "Containerized ZeroTier One for use on CoreOS or other Docker-only Linux hosts."

RUN apk add --no-cache --update libgcc libstdc++

COPY dist/usr/sbin/zerotier-one /zerotier-one

RUN chmod 0755 /zerotier-one && ln -sf /zerotier-one /zerotier-cli && ln -sf /zerotier-one /zerotier-idtool && mkdir -p /var/lib/zerotier-one

COPY main.sh /main.sh

RUN chmod 0755 /main.sh

ENTRYPOINT ["/bin/sh", "-c", "/main.sh"]
