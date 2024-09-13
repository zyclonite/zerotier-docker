## Adding of HealthCheck has been sponsored by PMGA Tech LLP.
#!/bin/sh

#Exit Codes
# 0= Success
# Failure

status=$(zerotier-cli status | awk '{print $5}')

if [[ "$status" = "ONLINE" ]] ; then
    exit 0
else
    exit 1
fi
