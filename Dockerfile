FROM debian:buster-slim

# zerotier-one version
ARG ZT_VERSION=1.4.6

LABEL maintainer="Lukas Prettenthaler (zyclonite)"
LABEL version="$ZT_VERSION"
LABEL description="Containerized ZeroTier One for use on CoreOS or other Docker-only Linux hosts."

# Configure environment
ENV ZT_VERSION=${ZT_VERSION}

RUN apt-get update \
 && apt-get install -y gnupg2 \
 && apt-key adv --fetch-keys http://download.zerotier.com/contact%40zerotier.com.gpg \
 && echo "deb http://download.zerotier.com/debian/buster buster main" > /etc/apt/sources.list.d/zerotier.list \
 && apt-get update \
 && apt-get install -y zerotier-one=${ZT_VERSION} \
 && rm -rf /var/lib/apt/lists/*

VOLUME /var/lib/zerotier-one
EXPOSE 9993

ENTRYPOINT ["zerotier-one"]
