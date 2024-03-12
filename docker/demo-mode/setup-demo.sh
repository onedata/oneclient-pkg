#!/bin/bash

source /root/demo-mode/better-curl.sh

AWAIT_ONEPROVIDER_TIMEOUT=600

ONEZONE_IP="$1"
ONEPROVIDER_IP="$2"

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
    do_curl -u "admin:password" "https://${ONEZONE_DOMAIN}/api/v3/onezone/providers" | jq '.providers'
}

main() {
    # A simple heuristic checking if the container is running in privileged mode, which
    # is required for Oneclient to be mounted (which requires access to the fusermount command).
    mkdir /tmp/mount_test
    if ! mount -t tmpfs tmpfs /tmp/mount_test/; then
        echo "ERROR: The Oneclient container must be run in privileged mode (use --privileged option)."
        exit_and_kill_docker
    fi
    umount /tmp/mount_test/

    echo "${ONEZONE_IP} ${ONEZONE_DOMAIN}" >> /etc/hosts

    echo -e "\e[1;33m"
    echo "-------------------------------------------------------------------------"
    echo "Starting Oneclient in demo mode..."
    echo "When the service is ready, an adequate log will appear here."
    echo "You may also use the await script: \"docker exec \$CONTAINER_ID await-demo\"."
    echo "-------------------------------------------------------------------------"
    echo -e "\e[0m"

    if ! await-demo-onezone; then
        exit_and_kill_docker
    fi

    if [[ -n "$ONEPROVIDER_IP" ]]; then
        echo "-------------------------------------------------------------------------"
        echo "Oneclient will connect to the user-specified Oneprovider at $ONEPROVIDER_IP."
        echo "-------------------------------------------------------------------------"
    else
        # get the number of oneproviders and randomly select one
        OP_COUNT=$(list_providers | jq 'length')
        RETRY_NUM=0
        while [[ $OP_COUNT == 0 ]]; do
            RETRY_NUM=$((RETRY_NUM + 1))

            if ! ((RETRY_NUM % 15)); then
                echo -e "\e[1;33m"
                echo "-------------------------------------------------------------------------"
                echo "Waiting for any Oneprovider service to be available..."
                echo "-------------------------------------------------------------------------"
                echo -e "\e[0m"
            fi

            if [[ ${RETRY_NUM} -eq ${AWAIT_ONEPROVIDER_TIMEOUT} ]]; then
                echo -e "\e[1;31m"
                echo "-------------------------------------------------------------------------"
                echo "ERROR: No Oneprovider service has become available within ${AWAIT_ONEPROVIDER_TIMEOUT} seconds."
                echo "Exiting..."
                echo "-------------------------------------------------------------------------"
                echo -e "\e[0m"
                exit_and_kill_docker
            fi

            sleep 1
            OP_COUNT=$(list_providers | jq 'length')
        done

        OP_ID=$(list_providers | jq -r .[$((RANDOM % OP_COUNT))])
        ONEPROVIDER_IP=$(
            do_curl -u "admin:password" "https://${ONEZONE_DOMAIN}/api/v3/onezone/providers/${OP_ID}" | jq -r .domain
        )

        echo "-------------------------------------------------------------------------"
        echo "Oneclient will connect to the randomly selected Oneprovider at $ONEPROVIDER_IP."
        echo "-------------------------------------------------------------------------"
    fi

    if ! await-supported-demo-space "$ONEPROVIDER_IP"; then
        exit_and_kill_docker
    fi

    ONECLIENT_PROVIDER_HOST=$ONEPROVIDER_IP
    ONECLIENT_ACCESS_TOKEN=$(demo-access-token)

    echo ""
    echo "-------------------------------------------------------------------------"
    echo "Access token: ${ONECLIENT_ACCESS_TOKEN}"
    echo "-------------------------------------------------------------------------"
    echo ""

    # export envs that are required by the oneclient application
    export ONECLIENT_PROVIDER_HOST
    export ONECLIENT_ACCESS_TOKEN

    # After the main process finishes here, the oneclient entrypoint is run.

    # Wait asynchronously for the demo-space to be mounted
    {
        if ! await-demo; then
            exit_and_kill_docker
        fi

        echo -e "\e[1;32m"
        echo "-------------------------------------------------------------------------"
        echo "Oneclient is ready!"
        echo "The demo space is mounted at /mnt/oneclient/demo-space in the container."
        echo "Example commands to try: "
        echo "  ~$ docker exec \$CONTAINER_ID bash -c 'echo test > /mnt/oneclient/demo-space/file.txt'"
        echo "  ~$ docker exec \$CONTAINER_ID ls /mnt/oneclient/demo-space"
        echo "  ~$ docker exec \$CONTAINER_ID cat /mnt/oneclient/demo-space/file.txt"
        echo "-------------------------------------------------------------------------"
        echo -e "\e[0m"
    } &
}

main "$@"
