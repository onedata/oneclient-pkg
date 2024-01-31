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

ONECLIENT_IP=$(hostname -I | tr -d ' ')

source /root/demo-mode/demo-common.sh

main() {
    HOSTNAME=$(hostname)
    echo "${ONEZONE_IP} ${ONEZONE_DOMAIN}" >> /etc/hosts

    cat /etc/hosts
    
    echo -e "\e[1;33m"
    echo "-------------------------------------------------------------------------"
    echo "Starting Oneclient in demo mode..."
    echo "-------------------------------------------------------------------------"
    echo -e "\e[0m"

    await-demo-onezone
    if [ -z $2 ]; then
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
	export ONECLIENT_PROVIDER_HOST=$2
    fi
    
    # Get access token
    if do_curl -k -u admin:password "https://onezone.local/api/v3/onezone/user/tokens/named/name/oneclient-access-token"; then 
	echo Token exists already
	export ONECLIENT_ACCESS_TOKEN=$(jq -r .token /tmp/curl-resp-body.txt)
    else
	echo Creating access token
	export ONECLIENT_ACCESS_TOKEN=$(curl -k -u admin:password \
		 "https://${ONEZONE_DOMAIN}/api/v3/onezone/user/tokens/named" \
		 -X POST -H 'Content-type: application/json' -d '
		 {	 
                     "name": "oneclient-access-token",
         	     "type": {"accessToken": {}}
                 }' | jq -r .token )
    fi
    echo ONECLIENT_ACCESS_TOKEN=$ONECLIENT_ACCESS_TOKEN

    # Wait for oneprovider readiness
    RETRY_NUM=0
    while ! curl -fk -H "x-auth-token:$ONECLIENT_ACCESS_TOKEN" -X POST \
	    "https://${ONECLIENT_PROVIDER_HOST}/api/v3/oneprovider/lookup-file-id/demo-space" \
	  &> /dev/null; do
	RETRY_NUM=$((RETRY_NUM + 1))

	if ! ((RETRY_NUM % 15)); then
            echo -e "\e[1;33m"
            echo "-------------------------------------------------------------------------"
            echo "Awaiting for the demo environment to be set up..."
            echo "-------------------------------------------------------------------------"
            echo -e "\e[0m"
	fi
	
	if [[ ${RETRY_NUM} -eq ${TIMEOUT} ]]; then
            echo -e "\e[1;31m"
            echo "-------------------------------------------------------------------------"
            echo "ERROR: The demo environment failed to be set up within ${TIMEOUT} seconds, exiting."
            echo "-------------------------------------------------------------------------"
            echo -e "\e[0m"
            exit 1
	fi

	sleep 1;
    done
    # while [ "${ONECLIENT_PROVIDER_ID}" = "" ]; do
    #     ONECLIENT_PROVIDER_ID="$(curl -k https://${ONECLIENT_PROVIDER_HOST}/configuration 2>/dev/null | tr ',     ' '\n' | grep 'providerId' | tr -d '"' | cut -d ':' -f 2)";
    #     if [ "$ONECLIENT_PROVIDER_ID" = "" ]; then
    #         echo "[main process] Cannot obtain ONECLIENT_PROVIDER_ID=$ONECLIENT_PROVIDER_ID of Oneprovider host=$ONECLIENT_PROVIDER_HOST";
    #         sleep 2;
    #     fi;
    # done;


    # echo -e "\e[1;32m"
    # echo "-------------------------------------------------------------------------"
    # echo " Mounting in /mnt/oneclient on container 
    # echo "-------------------------------------------------------------------------"
    # echo -e "\e[0m"

}

main "$@"
