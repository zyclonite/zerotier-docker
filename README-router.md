## zerotier router

### Description

This is a variation built on top of the zyclonite/zerotier container which implements a local network router. It is based upon the ZeroTier Knowledge Base article:

* [Route between ZeroTier and Physical Networks](https://docs.zerotier.com/route-between-phys-and-virt/)

Technically, the above approach could be described as a *half-router*:

* You can initiate connections *from* a remote client *to* devices on the LAN; but
* You can't initiate connections *to* the remote client *from* devices on the LAN.

This implementation extends the concept so that you have a choice of:

* Permitting remote clients to initiate connections with a devices on your LAN; or
* Permitting clients on your LAN to initiate connections with remote devices reachable across your ZeroTier Cloud network; or
* Both of the above (ie a full router).

### Command line example

``` console
$ docker run --name zerotier-one --device=/dev/net/tun \
  --network=host -d \
  --cap-add=NET_ADMIN --cap-add=NET_RAW --cap-add=SYS_ADMIN \
  --env TZ=Etc/UTC --env PUID=$(id -u) --env PGID=$(id -g) \
  --env ZEROTIER_ONE_LOCAL_PHYS=eth0 \
  --env ZEROTIER_ONE_USE_IPTABLES_NFT=true \
  --env ZEROTIER_ONE_GATEWAY_MODE=inbound \
  --env ZEROTIER_ONE_NETWORK_IDS=«yourDefaultNetworkID(s)» \
  -v /var/lib/zerotier-one:/var/lib/zerotier-one \
  zyclonite/zerotier:router
```

Note:

* Environment variables that can contain multiple values should be enclosed in quotes with the components separated by spaces. Example:

	``` console
	--env ZEROTIER_ONE_LOCAL_PHYS="eth0 wlan0"
	``` 

### Compose file example

``` yaml
---

services:
  zerotier:
    image: "zyclonite/zerotier:router"
    container_name: zerotier-one
    devices:
      - /dev/net/tun
    network_mode: host
    volumes:
      - '/var/lib/zerotier-one:/var/lib/zerotier-one'
    cap_add:
      - NET_ADMIN
      - SYS_ADMIN
      - NET_RAW
    restart: unless-stopped
    environment:
      - TZ=Etc/UTC
      - PUID=999
      - PGID=994
      - ZEROTIER_ONE_LOCAL_PHYS=eth0
      - ZEROTIER_ONE_USE_IPTABLES_NFT=true
      - ZEROTIER_ONE_GATEWAY_MODE=inbound
    # - ZEROTIER_ONE_NETWORK_IDS=«yourDefaultNetworkID(s)»
```

Note:

* The right hand sides of environment variables should *never* be enclosed in quotes.   If you need to pass multiple values, separate them with spaces. Example:

	``` yaml
	environment:
	- ZEROTIER_ONE_LOCAL_PHYS=eth0 wlan0
	``` 

### Environment variables

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

* `ZEROTIER_ONE_LOCAL_PHYS` - a space-separated list of physical interfaces that should be configured to participate in NAT-based routing. Examples:

	- Use only the physical Ethernet interface (this is also the default of the variable is omitted):

		``` yaml
		environment:
		- ZEROTIER_ONE_LOCAL_PHYS=eth0
		```

	- If your computer only has WiFi active (eg Raspberry Pi Zero W2):

		``` yaml
		environment:
		- ZEROTIER_ONE_LOCAL_PHYS=wlan0
		```

	- If your computer has both Ethernet and WiFi interfaces active and you wish to be able to route through each interface:

		``` yaml
		environment:
		- ZEROTIER_ONE_LOCAL_PHYS=eth0 wlan0
		```

		This scheme could be appropriate where the physical interfaces were:

		1. In the same broadcast domain (subnet). Disconnecting Ethernet would fail-over to WiFi.
		2. In different broadcast domains, such as if you allocated different subnets for Ethernet and WiFi.

* `ZEROTIER_ONE_USE_IPTABLES_NFT` - controls the command the container uses to set up net-filter rules to implement packet forwarding. Example:

	```
	 environment:
	 - ZEROTIER_ONE_USE_IPTABLES_NFT=true
	```

	* `false` means the container uses `iptables-legacy`. This is the default if the variable is omitted but that is only to maintain backwards compatibility.
	* `true` means the container uses `iptables-nft`. This is *generally* what you need.

	The way to be absolutely certain is to start the container and then run the following command:

	``` console
	$ sudo nft list ruleset | grep -c "zt*"
	```

	Ignore any lines that start with the `#` character.

	There are three possible responses:

	1. An error saying that the `nft` command has not been found. Docker uses `iptables-nft` to construct its own net-filter rules so it installs the `iptables` package as a dependency which, in turn, installs `nftables` as its own dependency. For that reason, not being able to find the `nft` command generally indicates an improper installation of Docker.
	2. A line-count of zero. This means the container has not been able to configure net-filter rules on the host. If that happens, try the opposite setting for this environment variable (eg `true` instead of `false`).
	3. A non-zero line-count. That means the container has been able to propagate net-filter rules into the host's tables, which is what you want. The actual number is not important, just something other than zero.

	The container will always come up. Once you've authorised the client in ZeroTier Central, it will be able to join your ZeroTier Cloud network. Tests like `ping` and `traceroute` that you run on the same host will always work. However, if the container is not able to propagate its net-filter rules into the host's tables, traffic *beyond* the host where the container is running will not work properly. The problem is quite subtle so it's always a good idea to check that the host has the expected net-filters.

* `ZEROTIER_ONE_GATEWAY_MODE` - controls the traffic direction. Examples:

	- Only permit traffic *from* the ZeroTier cloud *to* the local physical interfaces:

		``` yaml
		environment:
		- ZEROTIER_ONE_GATEWAY_MODE=inbound
		```

	- Only permit traffic *from* the local physical interfaces *to* the ZeroTier cloud:

		``` yaml
		environment:
		- ZEROTIER_ONE_GATEWAY_MODE=outbound
		```

	- Permit bi-directional traffic between the local physical interfaces and the ZeroTier cloud:

		``` yaml
		environment:
		- ZEROTIER_ONE_GATEWAY_MODE=both
		```

	Defaults to `inbound` if omitted. Note that you will probably need one or more static routes configured in your local LAN router so that traffic originating in a local host which is not running the ZeroTier client can be directed to the gateway host.

* `ZEROTIER_ONE_NETWORK_IDS` – a space-separated list of ZeroTier network IDs.

	This variable is *only* effective on first launch. There is no default if it is omitted. Examples:

	- to join a single network:

		``` yaml
		environment:
		- ZEROTIER_ONE_NETWORK_IDS=aaaaaaaaaaaaaaaa
		```

		Equivalent of running the following command after the container first starts:

		```
		$ docker exec zerotier zerotier-cli join aaaaaaaaaaaaaaaa
		```

	- to join a multiple networks:

		``` yaml
		environment:
		- ZEROTIER_ONE_NETWORK_IDS=aaaaaaaaaaaaaaaa bbbbbbbbbbbbbbbb
		```

		Equivalent of running the following commands after the container first starts:

		```
		$ docker exec zerotier zerotier-cli join aaaaaaaaaaaaaaaa
		$ docker exec zerotier zerotier-cli join bbbbbbbbbbbbbbbb
		```

	It does not matter whether you use this environment variable or the `join` command, you still need to use ZeroTier Central to approve the computer for each network it joins.

### Managed route(s)

For each ZeroTier container that is configured as a router, ZeroTier needs at least one *Managed Route*.

The [ZeroTier Wiki](https://docs.zerotier.com/route-between-phys-and-virt/#configure-the-zerotier-managed-route) explains how to design managed routes.

You configure Managed Routes in ZeroTier Central.

### Detailed examples

See:

* [SensorsIot/IOTstack - ZeroTier](https://sensorsiot.github.io/IOTstack/Containers/ZeroTier/)

You do not have to use IOTstack just to get ZeroTier running. However, the IOTstack documentation explores several network models and is a useful guide to the concepts involved and decisions you will need to make.

