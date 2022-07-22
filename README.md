[![Docker Pulls](https://badgen.net/docker/pulls/zyclonite/zerotier)](https://hub.docker.com/r/zyclonite/zerotier)
[![Quay.io Enabled](https://badgen.net/badge/quay%20pulls/enabled/green)](https://quay.io/repository/zyclonite/zerotier)
[![Multiarch build](https://github.com/zyclonite/zerotier-docker/actions/workflows/multiarch.yml/badge.svg)](https://github.com/zyclonite/zerotier-docker/actions/workflows/multiarch.yml)

## zerotier-docker

#### Description

This is a container based on a lightweight Alpine Linux image and a copy of ZeroTier One. It's designed to allow you to run ZeroTier One as a service on container-oriented distributions like Fedora CoreOS, though it should work on any Linux system with Docker or Podman.

#### Run

To run this container in the correct way requires some special options to give it special permissions and allow it to persist its files. Here's an example (tested on Fedora CoreOS):

    docker run --name zerotier-one --device=/dev/net/tun --net=host \
      --cap-add=NET_ADMIN --cap-add=SYS_ADMIN \
      -v /var/lib/zerotier-one:/var/lib/zerotier-one zyclonite/zerotier


This runs zyclonite/zerotier in a container with special network admin permissions and with access to the host's network stack (no network isolation) and /dev/net/tun to create tun/tap devices. This will allow it to create zt# interfaces on the host the way a copy of ZeroTier One running on the host would normally be able to.

In other words that basically does the same thing that running zerotier-one directly on the host would do, except it runs in a container. Since Fedora CoreOS has no package management this is the preferred way of distributing software for it.

It also mounts /var/lib/zerotier-one to /var/lib/zerotier-one inside the container, allowing your service container to persist its state across restarts of the container itself. If you don't do this it'll generate a new identity every time. You can put the actual data somewhere other than /var/lib/zerotier-one if you want.

To join a zerotier network you can use

    docker exec zerotier-one zerotier-cli join 8056c2e21c000001


or create an empty file with the network as name

    /var/lib/zerotier-one/networks.d/8056c2e21c000001.conf

#### Router mode
It is the implementation of the local network router [paper](https://zerotier.atlassian.net/wiki/spaces/SD/pages/224395274/Route+between+ZeroTier+and+Physical+Networks)

    docker run --name zerotier-one --device=/dev/net/tun \
      --cap-add=NET_ADMIN --cap-add=NET_RAW --cap-add=SYS_ADMIN \
      -v /var/lib/zerotier-one:/var/lib/zerotier-one zyclonite/zerotier:router

That will start the zero-one, establish connection and build the NAT+router once the `zt` interface is up.

##### Environment variables

The following environment variables are supported:

* `TZ` – timezone support. Example:

	``` yaml
	TZ=Australia/Sydney
	```

	Defaults to `Etc/UTC` if omitted.

* `PUID` + `PGID` – user and group IDs for ownership of persistent store. Example:

	``` yaml
	PUID=1000
	PGID=1000
	```
	
	If omitted, `PUID` defaults to user ID 999, while `PGID` defaults to group ID 994. These variables are only used to ensure consistent ownership on each launch. They do not affect how the container *runs.* Absent a `user:` directive, the container runs as root and does not downgrade its privileges.

* `ZEROTIER_ONE_LOCAL_PHYS` - controls which physical interfaces participate in network address translation (NAT). Examples:

	- Use only the physical Ethernet interface (this is also the default of the variable is omitted):

		``` yaml
		ZEROTIER_ONE_LOCAL_PHYS=eth0
		```

	- If your computer only has WiFi active:

		``` yaml
		ZEROTIER_ONE_LOCAL_PHYS=wlan0
		```
	
	- If your computer has both Ethernet and WiFi interfaces active and you wish to be able to route through each interface:

		- if using `docker run`:

			``` console
			--env ZEROTIER_ONE_LOCAL_PHYS="eth0 wlan0"
			```
	
		- if using `docker-compose`:

			``` yaml
			environment:
			- ZEROTIER_ONE_LOCAL_PHYS=eth0 wlan0
			```

* `ZEROTIER_ONE_USE_IPTABLES_NFT` - controls the command the container uses to set up NAT forwarding. Example:

	``` yaml
	ZEROTIER_ONE_USE_IPTABLES_NFT=true
	```

	Defaults to `false` if omitted. Try `true` if NAT does not seem to be working.
	
* `ZEROTIER_ONE_NETWORK_IDS` – auto-join network(s). This variable is only effective on first launch. There is no default if it is omitted. Examples:

	- if using `docker run`:

		``` console
		--env ZEROTIER_ONE_NETWORK_IDS="aaaaaaaaaaaaaaaa bbbbbbbbbbbbbbbb"
		```
	
	- if using `docker-compose`:

		``` yaml
		environment:
		- ZEROTIER_ONE_NETWORK_IDS=aaaaaaaaaaaaaaaa bbbbbbbbbbbbbbbb
		```

	In each case, it is the equivalent of running the following commands after the container first starts:
	
	```
	$ docker exec zerotier zerotier-cli join aaaaaaaaaaaaaaaa
	$ docker exec zerotier zerotier-cli join bbbbbbbbbbbbbbbb
	```

	It does not matter whether you use this environment variable or the `join` command, you still need to authorize the computer for each network in ZeroTier Central.

#### Source

https://github.com/zyclonite/zerotier-docker
