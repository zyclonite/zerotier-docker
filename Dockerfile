FROM alpine:3.11 as builder

ARG ZT_VERSION=1.4.6

RUN apk add --update alpine-sdk linux-headers \
  && git clone --depth 1 --branch ${ZT_VERSION} https://github.com/zerotier/ZeroTierOne.git /src \
  && cd /src \
  && make -f make-linux.mk

FROM alpine:3.11
LABEL version="1.4.6"
LABEL description="ZeroTier One Docker-only Linux hosts"

RUN apk add --update libgcc libc6-compat libstdc++

EXPOSE 9993/udp

COPY --from=builder /src/zerotier-one /usr/sbin/
RUN mkdir -p /var/lib/zerotier-one \
  && ln -s /usr/sbin/zerotier-one /usr/sbin/zerotier-idtool \
  && ln -s /usr/sbin/zerotier-one /usr/sbin/zerotier-cli

ENTRYPOINT ["zerotier-one"]
