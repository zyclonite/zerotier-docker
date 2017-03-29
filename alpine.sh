apk add --update alpine-sdk linux-headers
cd build
rm -rf dist/*
curl -s https://codeload.github.com/zerotier/ZeroTierOne/zip/1.2.2 -o zerotier-src.zip
unzip -q zerotier-src.zip
cd ./ZeroTierOne-1.2.2
make -f make-linux.mk
DESTDIR=/build/dist make -f make-linux.mk install

