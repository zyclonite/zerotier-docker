[![Docker Pulls](https://badgen.net/docker/pulls/zyclonite/zerotier)](https://hub.docker.com/r/zyclonite/zerotier)
[![Quay.io Enabled](https://badgen.net/badge/quay%20pulls/enabled/green)](https://quay.io/repository/zyclonite/zerotier)
[![Multiarch build](https://github.com/zyclonite/zerotier-docker/actions/workflows/multiarch.yml/badge.svg)](https://github.com/zyclonite/zerotier-docker/actions/workflows/multiarch.yml)

## zerotier-docker

#### Description

This is a container based on a lightweight Alpine Linux image and a copy of ZeroTier One. It's designed to allow you to run ZeroTier One as a service on container-oriented distributions like Fedora CoreOS, though it should work on any Linux system with Docker or Podman.

#### Run

To run this container in the correct way requires some special options to give it special permissions and allow it to persist its files. Here's an example (tested on Fedora CoreOS):

``` console
$ docker run --name zerotier-one --device=/dev/net/tun \
  --network=host -d \
  --cap-add=NET_ADMIN --cap-add=SYS_ADMIN \
  --env TZ=Etc/UTC --env PUID=$(id -u) --env PGID=$(id -g) \
  --env ZEROTIER_ONE_NETWORK_IDS=«yourDefaultNetworkID(s)» \
  -v /var/lib/zerotier-one:/var/lib/zerotier-one \
  zyclonite/zerotier
```

This runs zyclonite/zerotier in a container with special network admin permissions and with access to the host's network stack (no network isolation) and /dev/net/tun to create tun/tap devices. This will allow it to create zt# interfaces on the host the way a copy of ZeroTier One running on the host would normally be able to.

In other words that basically does the same thing that running zerotier-one directly on the host would do, except it runs in a container. Since Fedora CoreOS has no package management this is the preferred way of distributing software for it.

It also mounts /var/lib/zerotier-one to /var/lib/zerotier-one inside the container, allowing your service container to persist its state across restarts of the container itself. If you don't do this it'll generate a new identity every time. You can put the actual data somewhere other than /var/lib/zerotier-one if you want.

To join a zerotier network you can use any of the following methods, or a combination thereof:

1. The [`ZEROTIER_ONE_NETWORK_IDS`](#joinVar) environment variable. This, however, only works on first launch when the container's persistent store does not exist.

2. The command line:

	``` console
	$ docker exec zerotier-one zerotier-cli join «networkID»
	```

3. Create an empty file with the network as name:

	```
	/var/lib/zerotier-one/networks.d/«networkID».conf
	```

	and then restart the container.

#### compose file example

``` yaml
---

services:
  zerotier:
    image: zyclonite/zerotier
    container_name: zerotier-one
    devices:
      - /dev/net/tun
    network_mode: host
    volumes:
      - '/var/lib/zerotier-one:/var/lib/zerotier-one'
    cap_add:
      - NET_ADMIN
      - SYS_ADMIN
    restart: unless-stopped
    environment:
      - TZ=Etc/UTC
      - PUID=999
      - PGID=994
    # - ZEROTIER_ONE_NETWORK_IDS=«yourDefaultNetworkID(s)»
``` 

#### Environment variables

* `TZ` – timezone support. Example:

	``` yaml
	environment:
	- TZ=Australia/Sydney
	```

	Defaults to `Etc/UTC` if omitted.

* `PUID` + `PGID` – user and group IDs for ownership of persistent store. Example:

	``` yaml
	environment:
	- PUID=1000
	- PGID=1000
	```

	If omitted, `PUID` defaults to user ID 999, while `PGID` defaults to group ID 994.

	These variables are only used to ensure consistent ownership of persistent storage on each launch. They do not affect how the container *runs.* Absent a `user:` directive, the container runs as root and does not downgrade its privileges.

* <a name="joinVar"></a>
`ZEROTIER_ONE_NETWORK_IDS` – a space-separated list of ZeroTier network IDs.

	This variable is *only* effective on first launch. There is no default if it is omitted. Examples:

	- to join a single network:

		``` yaml
		environment:
		- ZEROTIER_ONE_NETWORK_IDS=aaaaaaaaaaaaaaaa
		```

		This is the equivalent of running the following command after the container first starts:

		```
		$ docker exec zerotier zerotier-cli join aaaaaaaaaaaaaaaa
		```

	- to join a multiple networks:

		``` yaml
		environment:
		- ZEROTIER_ONE_NETWORK_IDS=aaaaaaaaaaaaaaaa bbbbbbbbbbbbbbbb
		```

		This is the equivalent of running the following commands after the container starts for the first time:

		```
		$ docker exec zerotier zerotier-cli join aaaaaaaaaaaaaaaa
		$ docker exec zerotier zerotier-cli join bbbbbbbbbbbbbbbb
		```

	It does not matter whether you use this environment variable or the `join` command, you still need to use ZeroTier Central to approve the host for each network it joins.

<a name="healthCheck"></a>
##### Health Checking

The container (both client and router) runs a health-checking service. It works like this:

1. The (internal) path:

	```
	/var/lib/zerotier-one/networks.d/
	```
	
	contains zero or more files matching the pattern:
	
	```
	«networkID».conf
	```
	
	Each `.conf` file indicates a ZeroTier network which the container has been configured to join. The *count* of those files (which may be zero or more) is the "expected network count".

2. If the host's routing table does not contain the same number of direct routes to ZeroTier-associated interfaces as the *expected network count,* the container reports "unhealthy".

A container state of "unhealthy" only tells you that *something* is wrong. It does not tell you *what* is wrong. It is simply a hints to dig deeper.

One of the most common reasons for the container to report "unhealthy" is that you have instructed the ZeroTier client (running inside the container) to join a network for which it is not authorised. 

###### Why Health Checking checks routes

The `zerotier-cli` command running inside the container may report that a ZeroTier Network is "OK" even if the host is aware that the associated network interface is not actually functioning.

An entry in the host's routing table is a pinnacle artefact. A direct route to an interface will only be added to the host's routing table if the interface exists and is in a functioning state.

Each fully-functioning ZeroTier network that a client joins results in exactly one network interface and, therefore, exactly one direct route to that interface in the host's routing table.

Route insertion and withdrawal is both sensitive to network conditions and efficient so counting routes leads to fewer Type I (the container reporting "healthy" when it is not) and Type II (the container reporting "unhealthy" when it is not) errors. 

#### Router mode

A variation on the container which implements a local network router. See:

* [router README](./README-router.md)

#### Source

https://github.com/zyclonite/zerotier-docker
