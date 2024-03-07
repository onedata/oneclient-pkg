#!/bin/bash

source /root/demo-mode/better-curl.sh

ONEZONE_IP="$1"
ONEPROVIDER_IP="$2"
TIMEOUT=300

# Regular expression to match IPv4 address
IP_REGEX="^([0-9]{1,3}\.){3}[0-9]{1,3}$"


if [[ -z "${ONEZONE_IP}" ]]; then
    echo "ERROR: You must provide Onezone IP address as the first argument of the demo command, exiting."
    exit_and_kill_docker
fi

if [[ ! ${ONEZONE_IP} =~ $IP_REGEX ]]; then
    echo "ERROR: \"${ONEZONE_IP}\" does not look like a valid IP address, exiting."
    exit_and_kill_docker
fi

if [[ -n "${ONEPROVIDER_IP}" ]]; then
    if [[ ! ${ONEPROVIDER_IP} =~ $IP_REGEX ]]; then
        echo "ERROR: \"${ONEPROVIDER_IP}\" does not look like a valid IP address, exiting."
        exit_and_kill_docker
    fi
fi

list_providers() {
    do_curl -u "admin:password" https://onezone.local/api/v3/onezone/providers
}
    
main() {
    echo "${ONEZONE_IP} ${ONEZONE_DOMAIN}" >> /etc/hosts

    echo -e "\e[1;33m"
    echo "-------------------------------------------------------------------------"
    echo "Starting Oneclient in demo mode..."
    echo "When the service is ready, an adequate log will appear here."
    echo "You may also use the await script: \"docker exec \$CONTAINER_ID await-demo\"."
    echo "-------------------------------------------------------------------------"
    echo -e "\e[0m"

    await-demo-onezone
    if [ -z $ONEPROVIDER_IP ]; then
        # Get number of oneproviders and select randomly one 
        OP_NUM=$(list_providers | jq '.providers | length')
        RETRY_NUM=0
        while [[ $OP_NUM == 0 ]]; do
            RETRY_NUM=$((RETRY_NUM + 1))

            if ! ((RETRY_NUM % 15)); then
                echo -e "\e[1;33m"
                echo "-------------------------------------------------------------------------"
                echo "Awaiting for any Oneprovider service to be available......"
                echo "-------------------------------------------------------------------------"
                echo -e "\e[0m"
            fi
            
            if [[ ${RETRY_NUM} -eq ${TIMEOUT} ]]; then
                echo -e "\e[1;31m"
                echo "-------------------------------------------------------------------------"
                echo "ERROR: No Oneprovider service has become available within ${TIMEOUT} seconds." 
                echo "Exiting..."
                echo "-------------------------------------------------------------------------"
                echo -e "\e[0m"
                exit_and_kill_docker
            fi
            sleep 1
            OP_NUM=$(list_providers | jq '.providers | length')
        done
        OP=$((RANDOM % $OP_NUM))
        OP_ID=$(list_providers | jq -r .providers[$OP])
        ONEPROVIDER_IP=$(do_curl -u "admin:password" \
               https://onezone.local/api/v3/onezone/providers/${OP_ID} |\
               jq -r .domain)
    fi
    # export envs that are required by the oneclient application
    export ONECLIENT_PROVIDER_HOST=$ONEPROVIDER_IP
    export ONECLIENT_ACCESS_TOKEN=$(demo-access-token)    
    await-supported-demo-space $ONEPROVIDER_IP
    echo -e "\e[1;33m"
    echo "-------------------------------------------------------------------------"
    echo "Mounting Oneclient with the following parameters:"
    echo   ONECLIENT_PROVIDER_HOST=$ONECLIENT_PROVIDER_HOST
    echo   ONECLIENT_ACCESS_TOKEN=$ONECLIENT_ACCESS_TOKEN
    echo "-------------------------------------------------------------------------"
    echo -e "\e[0m"    

    # Wait asyncly for demo-space to appear in /mnt/oneclient
    {
        if ! await-demo; then
            exit_and_kill_docker
        fi

        echo -e "\e[1;32m"
        echo "-------------------------------------------------------------------------"
        echo "Oneclient is ready!"
        echo "The demo space is mounted under /mnt/oneclient/demo-space in the container."
        echo "-------------------------------------------------------------------------"
        echo -e "\e[0m"
    } &
}

main "$@"
