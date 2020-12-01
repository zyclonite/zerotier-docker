[![Docker Pulls](https://badgen.net/docker/pulls/zyclonite/zerotier)](https://hub.docker.com/r/zyclonite/zerotier)

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

    docker exec zerotier-one /zerotier-cli join 8056c2e21c000001


or create an empty file with the network as name

    /var/lib/zerotier-one/networks.d/8056c2e21c000001.conf

#### Source

https://github.com/zyclonite/zerotier-docker
