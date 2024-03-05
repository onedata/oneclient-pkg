#!/bin/bash

ONEZONE_IP="$1"
ONEPROVIDER_IP="$2"

# Regular expression to match IPv4 address
IP_REGEX="^([0-9]{1,3}\.){3}[0-9]{1,3}$"


if [[ -z "${ONEZONE_IP}" ]]; then
    echo "[ERROR] You must provide Onezone IP address as the first argument of the demo command, exiting."
    exit 1
fi

if [[ ! ${ONEZONE_IP} =~ $IP_REGEX ]]; then
    echo "[ERROR] \"${ONEZONE_IP}\" does not look like a valid IP address, exiting."
    exit 1
fi

if [[ ! -z "${ONEPROVIDER_IP}" ]]; then
    if [[ ! ${ONEPROVIDER_IP} =~ $IP_REGEX ]]; then
	echo "[ERROR] \"${ONEPROVIDER_IP}\" does not look like a valid IP address, exiting."
	exit 1
    fi
fi
    
source /root/demo-mode/better-curl.sh

main() {
    HOSTNAME=$(hostname)
    echo "${ONEZONE_IP} ${ONEZONE_DOMAIN}" >> /etc/hosts

    cat /etc/hosts
    
    echo -e "\e[1;33m"
    echo "-------------------------------------------------------------------------"
    echo "Starting Oneclient in demo mode..."
    echo "When the service is ready, an adequate log will appear here."
    echo "You may also use the await script: \"docker exec \$CONTAINER_ID await-demo-oneclient\"."
    echo "-------------------------------------------------------------------------"
    echo -e "\e[0m"

    await-demo-onezone
    if [ -z $ONEPROVIDER_IP ]; then
	# Get number of oneproviders and select randomly one 
	OP_NUM=$(curl -v -k -u "admin:password" https://onezone.local/api/v3/onezone/providers |\
		     jq '.providers | length')
	while [[ ${OP_NUM} == 0 ]]; do
	    sleep 2
	    OP_NUM=$(curl -v -k -u "admin:password" https://onezone.local/api/v3/onezone/providers |\
			 jq '.providers | length')
	    echo $OP_NUM
	done
	OP=$((RANDOM % $OP_NUM))
	OP_ID=$(curl -v -k -u "admin:password" https://onezone.local/api/v3/onezone/providers |\
		    jq -r .providers[$OP])
	export ONECLIENT_PROVIDER_HOST=$(curl -v -k -u "admin:password" \
	       https://onezone.local/api/v3/onezone/providers/${OP_ID} |\
	       jq -r .domain)
    else
	export ONECLIENT_PROVIDER_HOST=$ONEPROVIDER_IP
    fi
    echo -e "\e[1;33m"
    echo "-------------------------------------------------------------------------"
    echo "Attempting connection to Oneprovider at IP: $ONECLIENT_PROVIDER_HOST"
    echo "-------------------------------------------------------------------------"
    echo -e "\e[0m"    
    # Get access token
    export ONECLIENT_ACCESS_TOKEN=$(demo-access-token)
    echo ONECLIENT_ACCESS_TOKEN=$ONECLIENT_ACCESS_TOKEN
    await-supported-demo-space

    # Wait asyncly for demo-space to appear in /mnt/oneclient
    {
	if ! await-demo-oneclient; then
            exit_and_kill_docker
        fi

        echo -e "\e[1;32m"
        echo "-------------------------------------------------------------------------"
        echo "Oneclient is ready."
	echo "The demo space is mounted under /mnt/oneclient in the container"
        echo "-------------------------------------------------------------------------"
        echo -e "\e[0m"
    } &
}

main "$@"
