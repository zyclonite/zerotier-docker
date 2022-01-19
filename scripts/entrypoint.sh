#!/usr/bin/env sh

/usr/bin/supervisord --configuration /opt/supervisord.conf &
zerotier-one $@