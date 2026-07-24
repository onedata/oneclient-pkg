#!/bin/sh
set -e
#
# This script is meant for quick & easy install via:
#   'curl -sSL http://packages.onedata.org/oneclient.sh | sh'
# or:
#   'wget -qO- http://packages.onedata.org/oneclient.sh | sh'
# or to install specific oneclient package/version:
#   'curl -sSL http://packages.onedata.org/oneclient.sh | sh -s -- --package oneclient=21.02.1-1~jammy'
#   'curl -sSL http://packages.onedata.org/oneclient.sh | sh -s -- --version 21.02.1'
#

URL=http://packages.devel.onedata.org
RELEASE=25
PACKAGE=""
VERSION=""
NAME=""

usage() {
    echo 'Usage: oneclient.sh [--package <package> | --version <version> [ <name> ]]'
    echo '  <package> means complete package string with version, e.g., oneclient=25.0-1~noble'
    echo '  <version> means product version string, e.g., 25.0'
    echo '  <name> means just package name, e.g., oneclient'
    exit 1
}

while [ $# -gt 0 ]; do
    case "$1" in
	-p|--package)
	    if [ -z "$2" -o "$(echo "$2" | cut -c1)" = "-" ]; then
		echo "Error: --package requires a value."
		exit 1
	    fi
	    PACKAGE="$2"
	    shift 2 # Move past the flag and the value
	    ;;
	-v|--version)
	    if [ -z "$2" -o "$(echo "$2" | cut -c1)" = "-" ]; then
		echo "Error: --version requires a value."
		exit 1
	    fi
	    VERSION="$2"
	    shift 2 # Move past the flag and the value
	    ;;
        -*)
            echo "Error: Unknown option $1"
            usage
            ;;
        *)
            # If NAME is already set, we have too many positional arguments
            if [ -n "$NAME" ]; then
                echo "Error: Too many arguments."
                usage
            fi
            NAME="$1"
            shift
            ;;
    esac
done

if [ -n "$PACKAGE" -a -n "$VERSION" ]; then
    echo "Error: You cannot use --package and --version together."
    usage
fi
if [ -n "$PACKAGE" -a -n "$NAME" ]; then
    echo 'Error: You cannot use --package and <name> together.'
    usage
fi

command_exists() {
	command -v "$@" > /dev/null 2>&1
}

echo_configuration() {
    echo "Installation has been completed successfully."
    if [ -z "${NAME}" -o "${NAME}" = 'oneclient' ]; then
	echo "Run 'oneclient --help' for usage info."
    fi
}

do_install() {
	case "$(uname -m)" in
		*64)
			;;
		*)
			cat >&2 <<-'EOF'
			Error: you are not using a 64bit platform.
			onedata currently only supports 64bit platforms.
			EOF
			exit 1
			;;
	esac

	if command_exists oneclient; then
		cat >&2 <<-'EOF'
		Warning: "oneclient" command appears to already exist.
		Please ensure that you do not already have oneclient installed.
		You may press Ctrl+C now to abort this process and rectify this situation.
		EOF
		( set -x; sleep 20 )
	fi

	user="$(id -un 2>/dev/null || true)"

	sh_c='sh -c'
	if [ "$user" != 'root' ]; then
		if command_exists sudo; then
			sh_c='sudo -E sh -c'
		elif command_exists su; then
			sh_c='su -c'
		else
			cat >&2 <<-'EOF'
			Error: this installer needs the ability to run commands as root.
			We are unable to find either "sudo" or "su" available to make this happen.
			EOF
			exit 1
		fi
	fi

	curl=''
	if command_exists curl; then
		curl='curl -sSL'
	elif command_exists wget; then
		curl='wget -qO-'
	fi

	# perform some very rudimentary platform detection
	lsb_dist=''
	if command_exists lsb_release; then
		lsb_dist="$(lsb_release -sic  | tr '\n' - | rev | cut -c 2- | rev)"
	fi
	if [ -z "$lsb_dist" ] && [ -r /etc/lsb-release ]; then
		lsb_dist="$(. /etc/lsb-release && echo "$DISTRIB_ID-$DISTRIB_CODENAME")"
	fi
	if [ -z "$lsb_dist" ] && [ -r /etc/debian_version ]; then
		lsb_dist='debian'
	fi
	if [ -z "$lsb_dist" ] && [ -r /etc/fedora-release ]; then
		lsb_dist='fedora'
	fi
	if [ -z "$lsb_dist" ] && [ -r /etc/os-release ]; then
		lsb_dist="$(. /etc/os-release && echo "$ID")"
	fi
	if [ -z "$lsb_dist" ] && [ -r /etc/redhat-release ]; then
		lsb_dist="$(cat /etc/redhat-release | awk '{ print $1 }')"
	fi

	lsb_dist="$(echo "$lsb_dist" | tr '[:upper:]' '[:lower:]')"

    if [ -z "$PACKAGE" ] && [ -z "$VERSION" ] && [ -z "$NAME" ]; then
        PACKAGE="oneclient"
    elif [ "${lsb_dist%-*}" = 'ubuntu' ]; then
        if [ -n "$VERSION" ]; then
            if [ "${VERSION%%.*}" -lt 25 ]; then
                RELEASE=$(echo "$VERSION" | cut -d. -f1,2 | tr -d '.')
            else
                RELEASE=$(echo "$VERSION" | cut -d. -f1)
            fi

            if [ -n "$NAME" ]; then
                PACKAGE="${NAME}=${VERSION}-1~${lsb_dist#*-}"
            else
                PACKAGE="oneclient=${VERSION}-1~${lsb_dist#*-}"
            fi
        else
            VERSION="${PACKAGE#*=}"
            VERSION="${VERSION%-*}"

            if [ "${VERSION%%.*}" -lt 25 ]; then
                RELEASE=$(echo "$VERSION" | cut -d. -f1,2 | tr -d '.')
            else
                RELEASE=$(echo "$VERSION" | cut -d. -f1)
            fi
        fi
    fi

	case "$lsb_dist" in
		ubuntu-xenial)
			# onedata repo
			$sh_c "$curl ${URL}/onedata.gpg.key | apt-key add -"
			$sh_c "echo \"deb [arch=amd64] ${URL}/apt/ubuntu/${RELEASE} xenial main\" > /etc/apt/sources.list.d/onedata.list"
			$sh_c "echo \"deb-src [arch=amd64] ${URL}/apt/ubuntu/${RELEASE} xenial main\" >> /etc/apt/sources.list.d/onedata.list"
			$sh_c "apt-get update && apt-get install -y ${PACKAGE}"
			echo_configuration
			exit 0
			;;
		ubuntu-bionic)
			# onedata repo
			$sh_c "apt-get update && apt-get install -y gnupg"
			$sh_c "$curl ${URL}/onedata.gpg.key | apt-key add -"
			$sh_c "echo \"deb [arch=amd64] ${URL}/apt/ubuntu/${RELEASE} bionic main\" > /etc/apt/sources.list.d/onedata.list"
			$sh_c "echo \"deb-src [arch=amd64] ${URL}/apt/ubuntu/${RELEASE} bionic main\" >> /etc/apt/sources.list.d/onedata.list"
			$sh_c "apt-get update && apt-get install -y ${PACKAGE}"
			echo_configuration
			exit 0
			;;
		ubuntu-focal)
		        # onedata repo
			$sh_c "apt-get update && apt-get install -y gnupg"
			$sh_c "$curl ${URL}/onedata.gpg.key | apt-key add -"
			$sh_c "echo \"deb [arch=amd64] ${URL}/apt/ubuntu/${RELEASE} focal main\" > /etc/apt/sources.list.d/onedata.list"
			$sh_c "echo \"deb-src [arch=amd64] ${URL}/apt/ubuntu/${RELEASE} focal main\" >> /etc/apt/sources.list.d/onedata.list"

			$sh_c "apt-get update && apt-get install -y ${PACKAGE}"
			echo_configuration
			exit 0
			;;
		ubuntu-jammy)
			# onedata repo
			$sh_c "apt-get update && apt-get install -y gnupg"
			$sh_c "$curl ${URL}/onedata.gpg.key | apt-key add -"
			$sh_c "echo \"deb [arch=amd64] ${URL}/apt/ubuntu/${RELEASE} jammy main\" > /etc/apt/sources.list.d/onedata.list"
			$sh_c "echo \"deb-src [arch=amd64] ${URL}/apt/ubuntu/${RELEASE} jammy main\" >> /etc/apt/sources.list.d/onedata.list"

			$sh_c "apt-get update && apt-get install -y ${PACKAGE}"
			echo_configuration
			exit 0
			;;
		ubuntu-noble)
			# onedata repo
			$sh_c "apt-get update && apt-get install -y gpg"
			$sh_c "$curl ${URL}/onedata.gpg.key | gpg --dearmor --yes -o /usr/share/keyrings/onedata.gpg"
			$sh_c "echo \"deb [arch=amd64 signed-by=/usr/share/keyrings/onedata.gpg] ${URL}/apt/ubuntu/${RELEASE} noble main\" > /etc/apt/sources.list.d/onedata.list"
			$sh_c "echo \"deb-src [arch=amd64 signed-by=/usr/share/keyrings/onedata.gpg] ${URL}/apt/ubuntu/${RELEASE} noble main\" >> /etc/apt/sources.list.d/onedata.list"

			$sh_c "apt-get update && apt-get install -y ${PACKAGE}"
			echo_configuration
			exit 0
			;;
                ##############################################################################################
                # Fedora and centos|rocky packages are not supported now but may be supported in the future. #
                ##############################################################################################
		# fedora)
		# 	# onedata repo
		# 	$sh_c "$curl ${URL}/yum/${RELEASE}/onedata_fedora_29.repo > /etc/yum.repos.d/onedata.repo"

		# 	$sh_c "dnf -y --enablerepo=onedata install ${PACKAGE}"
		# 	echo_configuration
		# 	exit 0
		# 	;;
		# centos|rocky)
		# 	# onedata repo
		# 	$sh_c "$curl ${URL}/yum/${RELEASE}/onedata_centos_7x.repo > /etc/yum.repos.d/onedata.repo"

		# 	$sh_c "yum -y install epel-release"
		# 	$sh_c "yum -y --enablerepo=onedata install ${PACKAGE}"
		# 	echo_configuration
		# 	exit 0
	esac

	# intentionally mixed spaces and tabs here -- tabs are stripped by "<<-'EOF'", spaces are kept in the output
	cat >&2 <<-'EOF'

	  Either your platform is not easily detectable, is not supported by this
	  installer script, or does not yet have a package for oneclient.
	  Currently supported distributions are: ubuntu trusty, ubuntu wily, ubuntu xenial, centos 7 and fedora 23
	EOF
	exit 1
}

# wrapped up in a function so that we have some protection against only getting
# half the file during "curl | sh"
do_install
