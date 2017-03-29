docker run --rm -v $(pwd)/dist:/build/dist -v $(pwd)/alpine.sh:/alpine.sh -it alpine:3.5 sh /alpine.sh
docker build -t zyclonite/zerotier .
