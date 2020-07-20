#!/bin/bash

# ***********************************************
#  Info: Test Automation script
#
#  Usage 1:
#       Change following user parameters directly.
#       Set up TEST_PACKAGE and TEST_CASE (if need), then choose which
#       server should run the test (TEST_MACHINE_IP, TEST_HOST_IP)
#       Finally add EXTRA_PARAMS if need.
#
#  Usage 2:
#       Passing test paramters from shell. ex:
#       bash TEST_PACKAGE="redfish/service_root" single_test.sh
#       mark the TEST_CASE line if need test whole test suite.
#
# ***********************************************


# [User Parameter] we can pass these parameters from outside
TEST_PACKAGE=${TEST_PACKAGE:="redfish/service_root"}
TEST_MACHINE_IP=${TEST_MACHINE_IP:="10.103.152.12"}
TEST_HOST_IP=${TEST_HOST_IP:="10.103.152.206"}
# TEST_CASE=""
TEST_CASE=${TEST_CASE:="Redfish Login And Logout"}
EXTRA_PARAMS=""
COPY_IMAGE_DATA="N"
REMOTE_PC=${REMOTE_PC:="10.103.152.11"}


# fixed parameters
ROBOT_PARAMS="-v OPENBMC_HOST:${TEST_MACHINE_IP} -v OPENBMC_USERNAME:root -v OPENBMC_PASSWORD:0penBmc \
-v OS_HOST:${TEST_HOST_IP} -v OS_USERNAME:root -v OS_PASSWORD:cs20 -v TFTP_SERVER:10.103.152.11 \
-v REMOTE_LOG_SERVER_HOST:10.103.152.11 -v REMOTE_LOG_SERVER_PORT:514 -v REMOTE_USERNAME:root \
-v REMOTE_PASSWORD:cs20 -v SFTP_SERVER:10.103.152.11 -v SFTP_USER:cs20 -v SFTP_PATH:/tftpboot \
-v IPMI_INBAND_CMD:ipmitool"
ARG_FILE="test_lists/skip_test_olympus_nuvoton"
LOCAL_ROBOT="n"
# separate by | for regular expression
LOCAL_TEST_GROUP="update_service\|dmtf_tools\|service_root" # service_root can run both side
# enable debug flag for avoid real execute command
_DEBUG="n"

#
# $1 test group 
#
get_test_parameters(){
_res=`echo $1 | grep -e "$LOCAL_TEST_GROUP"`
if [ -n "$_res" ];then
    LOCAL_ROBOT="y"
    if [ "$1" == "dmtf_tools" ];then
        EXTRA_PARAMS+=" -e \"Run_Redfish_Service_Validator_With_Additional_Roles\""
        EXTRA_PARAMS+=" -v min_number_sensors:1"
    fi
fi
}

# 
# $1 test group  like "redfish/extended"
# $2 test case   like "Redfish Failure to Upload Empty Host Image"
# Note: in most case, run single test on server is not much useful
#
function perform_remote_test(){
TEST_GROUP="$1"

get_test_parameters "$TEST_GROUP"

if [ "$LOCAL_ROBOT" == "y" ];then
    ROBOT="/usr/local/bin/robot"
    OUTDIR="reports/${BUILD_ID}/${TEST_GROUP}"
else
    ROBOT="robot"
    OUTDIR="reports/${TEST_GROUP}"
fi
CMD="${ROBOT} --argumentfile ${ARG_FILE} --outputdir ${OUTDIR}"
if [ -n "$2" ];then
  CMD+=" -t \"$2\""
fi
if [ -n "$EXTRA_PARAMS" ];then
  CMD+=" $EXTRA_PARAMS"
fi
CMD+=" ${ROBOT_PARAMS} ${TEST_GROUP}"
echo "CMD: ${CMD}"

if [ "$_DEBUG" == "y" ];then
    exit 0 # do not real execute test command
fi

if [ "$LOCAL_ROBOT" == "y" ];then
/bin/bash <<-EOT
    ${CMD}
EOT

else # use remote lab pc run tests
ssh cs20@${REMOTE_PC} /bin/bash <<-EOT
    source /home/cs20/anaconda3/etc/profile.d/conda.sh
    conda activate openbmc
    cd OpenBMC-Test-Automation
    /usr/bin/env ${CMD}
    echo ${CMD}> cmd
EOT
fi
}

# ==== copy image dir === 
if [ "${COPY_IMAGE_DATA}" == "y" ];then
scp cs20@10.103.152.11:/tftpboot/test_1.static.mtd.all.tar test_1.static.mtd.all.tar
scp cs20@10.103.152.11:/tftpboot/test_2.static.mtd.all.tar test_2.static.mtd.all.tar
scp cs20@10.103.152.11:/tftpboot/test_1.static.mtd.tar test_1.static.mtd.tar
scp cs20@10.103.152.11:/tftpboot/test_2.static.mtd.tar test_2.static.mtd.tar
scp cs20@10.103.152.11:/tftpboot/test_3.static.mtd.tar test_3.static.mtd.tar
scp cs20@10.103.152.11:/tftpboot/bios6.tar bios6.tar
scp cs20@10.103.152.11:/tftpboot/bios7.tar bios7.tar
scp cs20@10.103.152.11:/tftpboot/bios_bad_manifest.bios.tar bios_bad_manifest.bios.tar
scp cs20@10.103.152.11:/tftpboot/bios_no_image.bios.tar bios_no_image.bios.tar
scp cs20@10.103.152.11:/tftpboot/bmc_bad_manifest.static.mtd.tar bmc_bad_manifest.static.mtd.tar
scp cs20@10.103.152.11:/tftpboot/bmc_bad_unsig.static.mtd.tar bmc_bad_unsig.static.mtd.tar
scp cs20@10.103.152.11:/tftpboot/bmc_nokernel_image.static.mtd.tar bmc_nokernel_image.static.mtd.tar
fi


if [ "$_DEBUG" != "y" ];then
# === clean up old log ===
mkdir -p reports/${BUILD_ID}
ssh cs20@10.103.152.11 /bin/bash <<-EOT
   rsync -avz cs20@172.19.1.23:/scratch/docker-jenkins/jenkins_home/workspace/single-Test-Automation . --exclude logs --exclude reports
   cd OpenBMC-Test-Automation
   #rm -rf reports/*
EOT
fi
# === real run section ===
echo "=== starting test $(date +'%x %X') ==="
perform_remote_test "${TEST_PACKAGE}" "${TEST_CASE}"




# === backup section ===
if [ "0" == "" ];then

perform_remote_test ipmi
perform_remote_test redfish/service_root
perform_remote_test system
perform_remote_test managers
perform_remote_test redfish/account_service
perform_remote_test redfish/extended
perform_remote_test nuvoton

perform_remote_test redfish/update_service
perform_remote_test redfish/dmtf_tools
#perform_remote_test redfish/service_root


#/usr/local/bin/robot --argumentfile test_lists/skip_test_olympus_nuvoton --outputdir \
#    reports/${BUILD_ID}/redfish/update_service ${ROBOT_PARAMS} redfish/update_service
#/usr/local/bin/robot --argumentfile test_lists/skip_test_olympus_nuvoton --outputdir \
#    reports/${BUILD_ID}/redfish/dmtf_tools -e "Run_Redfish_Service_Validator_With_Additional_Roles" \
#    ${ROBOT_PARAMS} -v min_number_sensors:1 redfish/dmtf_tools
#/usr/local/bin/robot --argumentfile test_lists/skip_test_olympus_nuvoton --outputdir \
#    reports/${BUILD_ID}/redfish/service_root ${ROBOT_PARAMS} redfish/service_root
fi

# === copy log ===
if [ "$LOCAL_ROBOT" != "y" ];then
scp -r cs20@10.103.152.11:OpenBMC-Test-Automation/reports/* reports/${BUILD_ID}/
fi

