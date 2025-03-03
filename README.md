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

You can also pass the following [Health Checking environment variables](#healthVars) to the `docker run` command:

```
  --env ZEROTIER_ONE_CHK_SPECIFIC_NETWORKS=«yourNetworkID(s)toCheck» \
  --env ZEROTIER_ONE_CHK_MIN_ROUTES_FOR_HEALTH=1 \
```

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
    # - ZEROTIER_ONE_CHK_SPECIFIC_NETWORKS=«yourNetworkID(s)toCheck»
    # - ZEROTIER_ONE_CHK_MIN_ROUTES_FOR_HEALTH=1
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

		This is the equivalent of running the following commands after the container first starts:

		```
		$ docker exec zerotier zerotier-cli join aaaaaaaaaaaaaaaa
		$ docker exec zerotier zerotier-cli join bbbbbbbbbbbbbbbb
		```

	It does not matter whether you use this environment variable or the `join` command, you still need to use ZeroTier Central to approve the host for each network it joins.

<a name="healthVars"></a>
##### Health Checking variables

The container (both client and router) runs a health-checking service. Two environment variables control its behaviour:

* `ZEROTIER_ONE_CHK_SPECIFIC_NETWORKS` – a space-separated list of ZeroTier network IDs.

	If this variable is present, the health check returns "healthy" providing that all listed network IDs meet the following criteria:

	- the network ID is known to the ZeroTier One client running in the container **and** has the status of "OK". It is the equivalent of running:

		``` console
		$ docker exec zerotier zerotier-cli get aaaaaaaaaaaaaaaa status
		OK
		```

	- If the network is known and "OK", the host's routing table is also checked for the presence of at least one direct route to the associated network interface.

	This variable takes precedence over checking for a minimum number of routes, which is described next.

* `ZEROTIER_ONE_CHK_MIN_ROUTES_FOR_HEALTH` - an unsigned numeric value greater than zero. Defaults to 1.

	This variable is only active if the check for specific networks (described above) is omitted.

	This form of health check returns "healthy" providing that the host's routing table contains at least as many direct routes to ZeroTier-associated interfaces as are specified by this variable.

	If your container joins exactly one ZeroTier Network then the default value of 1 is appropriate.

	If your container joins more than one network then whether you should increase the value of this variable to match depends on considerations such as:

	- whether multiple networks represent alternate paths; or
	- whether *you* still regard the service as healthy if only a subset of networks remain viable.

###### First Launch considerations

In a first-launch situation where the container's persistent store is initialised from scratch:

1. The container will report "unhealthy" until at least one ZeroTier network has been joined **and** the host has been approved in ZeroTier Central.
2. If health-checking is configured to check for specific networks then the container will report "unhealthy" until **all** specified networks have been joined **and** the host has been approved to join **each** network in ZeroTier Central.

###### Why Health Checking checks routes

The `zerotier-cli` command running inside the container may report that a ZeroTier Network is "OK" even if the host is aware that the associated network interface is not actually functioning.

An entry in the host's routing table is a pinnacle artefact. A direct route to an interface will only be added to the host's routing table if the interface exists and is in a functioning state.

Typically, each fully-functioning ZeroTier network that a client joins results in exactly one network interface and, therefore, exactly one direct route to that interface in the host's routing table.

Route insertion and withdrawal is both sensitive to network conditions and efficient so using routes to confirm `zerotier-cli` status reports leads to fewer Type I (the container reporting "healthy" when it is not) and Type II (the container reporting "unhealthy" when it is not) errors. 

#### Router mode

A variation on the container which implements a local network router. See:

* [router README](./README-router.md)

#### Source

https://github.com/zyclonite/zerotier-docker
