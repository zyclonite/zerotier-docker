ARG ALPINE_IMAGE
ARG ALPINE_VERSION=3.14
ARG ZT_COMMIT=e8f7d5ef9e7ba6be0b2163cfa31f8817ba5b18f4
ARG ZT_VERSION=1.6.5

FROM ${ALPINE_IMAGE}:${ALPINE_VERSION} as builder

RUN apk add --update alpine-sdk linux-headers \
  && git clone --quiet https://github.com/zerotier/ZeroTierOne.git /src \
  && git -C src reset --quiet --hard ${ZT_COMMIT} \
  && cd /src \
  && make -f make-linux.mk

FROM ${ALPINE_IMAGE}:${ALPINE_VERSION}
LABEL version="${ZT_VERSION}"
LABEL description="ZeroTier One as Docker Image"

RUN apk add --update --no-cache libc6-compat libstdc++

EXPOSE 9993/udp

COPY --from=builder /src/zerotier-one /usr/sbin/
RUN mkdir -p /var/lib/zerotier-one \
  && ln -s /usr/sbin/zerotier-one /usr/sbin/zerotier-idtool \
  && ln -s /usr/sbin/zerotier-one /usr/sbin/zerotier-cli

ENTRYPOINT ["zerotier-one"]
