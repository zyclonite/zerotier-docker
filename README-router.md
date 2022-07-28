## zerotier router

### Description

This is a variation built on top of the zyclonite/zerotier container which implements a local network router. It is based upon the ZeroTier Knowledge Base article:

* [Route between ZeroTier and Physical Networks](https://zerotier.atlassian.net/wiki/spaces/SD/pages/224395274/Route+between+ZeroTier+and+Physical+Networks)

Technically, this could be described as a *half-router*:

* You can initiate connections *from* a remote client *to* devices on the LAN; but
* You can't initiate connections *to* the remote client *from* devices on the LAN.

### Command line example

``` console
$ docker run --name zerotier-one --device=/dev/net/tun \
  --cap-add=NET_ADMIN --cap-add=NET_RAW --cap-add=SYS_ADMIN \
  --env TZ=Etc/UTC --env PUID=999 -env PGID=994 \
  --env ZEROTIER_ONE_LOCAL_PHYS=eth0 \
  --env ZEROTIER_ONE_USE_IPTABLES_NFT=false \
  --env ZEROTIER_ONE_GATEWAY_MODE=inbound \
  --env ZEROTIER_ONE_NETWORK_IDS=«yourDefaultNetworkID(s)» \
  -v /var/lib/zerotier-one:/var/lib/zerotier-one zyclonite/zerotier:router
```

Note:

* Environment variables that can contain multiple values should be enclosed in quotes with the components separated by spaces. Example:

	``` console
	--env ZEROTIER_ONE_LOCAL_PHYS="eth0 wlan0"
	``` 

### Compose file example

``` yaml
version: '3'
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
      - ZEROTIER_ONE_USE_IPTABLES_NFT=false
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

* `ZEROTIER_ONE_USE_IPTABLES_NFT` - controls the command the container uses to set up NAT forwarding. Example:

	``` yaml
	environment:
	- ZEROTIER_ONE_USE_IPTABLES_NFT=true
	```
	
	- `false` means the container uses `iptables`. This is the default.
	- `true` means the container uses `iptables-nft`.

	Try `true` if NAT does not seem to be working. This is needed on Raspberry Pi Bullseye.
	
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

The [ZeroTier Wiki](https://zerotier.atlassian.net/wiki/spaces/SD/pages/224395274/Route+between+ZeroTier+and+Physical+Networks#Configure-the-ZeroTier-managed-route) explains how to design managed routes.

You configure Managed Routes in ZeroTier Central.
