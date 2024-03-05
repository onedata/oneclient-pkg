#!/bin/bash
###-------------------------------------------------------------------
### Author: Lukasz Opiola
### Copyright (C): 2024 ACK CYFRONET AGH
### This software is released under the MIT license cited in 'LICENSE.txt'.
###-------------------------------------------------------------------
### Constants and functions used in the demo mode related scripts.
###-------------------------------------------------------------------

export ONEZONE_DOMAIN="onezone.local"  # this is put in /etc/hosts to make it resolvable


exit_and_kill_docker() {
    kill -9 "$(pgrep -f /root/run.sh)"
    exit 1
}



