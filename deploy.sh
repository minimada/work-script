#!/bin/bash
#
# test command: -b 192.168.56.130 -h 10.103.152.11 -i /share/issues/stress_test/buv/test_1.static.mtd.all.tar
# 
set -eo pipefail

Usage(){
    echo `basename $0` "[-ijlmf data]"
    echo "      -i : set data as image path"
    echo "      -j : set data as image max"
    echo "      -l : set data as log path"
    echo "      -m : set data as log max"
    echo "      -f : set data as backup project folder"
    exit 1
}

# Definitions
OBMC_PW='{"username":"root","password":"0penBmc"}'

# Functions
# $@ : all data need to print when set verbose
print_v(){
	if [ "$verbose" == "y" ];then
		echo $@
	fi
}

print_end(){
	echo $@ $(date)
}

# login OpenBMC web and get access token
# $1 : target BMC IP address
get_bmc_token(){
	local msg=`curl -k -H "Content-Type: application/json" -X POST https://${BMC_IP}/login -d ${OBMC_PW} 2>/dev/null| grep token`
	print_v "msg: $msg"
	token=`echo $msg | awk '{print $2;}' | tr -d '"'`
	print_v "token: $token"
}

# upload new BMC FW and reset BMC for perform FW update process
# $1 : FW image 
# $token  : BMC access token
# $BMC_IP : BMC IP address
update_bmc(){
	# set apply new BMC FW after reset
	curl -k -H "X-Auth-Token: $token" -X PATCH -d '{ "HttpPushUriOptions": { "HttpPushUriApplyTime": { "ApplyTime":"OnReset"}}}' https://${BMC_IP}/redfish/v1/UpdateService
	curl -k -H "X-Auth-Token: $token" -H "Content-Type: application/octet-stream" -X POST -T $1 https://${BMC_IP}/redfish/v1/UpdateService
	# wait BMC software manager create object for new image
	sleep 60
	curl -k -H "X-Auth-Token: $token" -X POST https://${BMC_IP}/redfish/v1/Managers/bmc/Actions/Manager.Reset -d '{"ResetType": "GracefulRestart"}'
	# need sleep some time...
}

# perfrom BMC factory reset
# $token  : BMC access token
# $BMC_IP : BMC IP address
reset_bmc(){
	curl -k -H "X-Auth-Token: $token" -X POST https://${BMC_IP}/redfish/v1/Managers/bmc/Actions/Manager.ResetToDefaults -d '{"ResetToDefaultsType": "ResetAll"}'
}

parse_arg(){
	while getopts ":b:h:i:v" argv;do
		case "$argv" in
			b)
				BMC_IP=${OPTARG}
				;;
			h)
				HOST_IP=${OPTARG}
				;;
			v)
				verbose="y"
				;;
			i)
				IMAGE_NAME=${OPTARG}
				;;
			*)
				Usage
				;;
		esac
	done
	shift $((OPTIND-1))

	if [ -z "$BMC_IP" ];then
		echo "BMC IP cannot empty"
		Usage
	fi
	if [ -z "$IMAGE_NAME" ];then
		echo "Image path cannot empty"
		Usage
	fi
}

# Main
parse_arg $@

token=""
get_bmc_token
if [ -z "$token" ];then
	print_end "get BMC token failed..."
	exit 1
fi

#exit
update_bmc $IMAGE_NAME
sleep 600
reset_bmc
sleep 300

print_end "Firmware update finished..."
exit 0
