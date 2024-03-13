#!/usr/bin/env bash

if [ "$1x" == "demox" ]; then
    source /root/demo-mode/setup-demo.sh "${2}" "${3}"
    /opt/oneclient/bin/oneclient -f /mnt/oneclient --force-proxy-io
else
    /opt/oneclient/bin/oneclient -f "$@"
fi
