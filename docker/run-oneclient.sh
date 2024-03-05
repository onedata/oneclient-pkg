#!/usr/bin/env bash

if [ $1"x" == "demox" ]; then
    source /root/demo-mode/setup-demo.sh "${2}" "${3}"
    /opt/oneclient/bin/oneclient -f /mnt/oneclient
else
    /opt/oneclient/bin/oneclient -f "$@"
fi


