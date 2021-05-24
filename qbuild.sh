#!/bin/bash

# ***********************************************
#  Info : build script for Nuvoton openbmc project
#
#  Usage:
#       qbuild
#       qbuild [target] [option]
#
# ***********************************************

# parameters
UBOOT_BUILD="n"
TARGET="obmc-phosphor-image"
DEFAULT_CONF=${CONF}
DEBUG=${DEBUG:="n"}

# fixed parameters
# oe-buildenv-internal will get BDIR from $2, we need to set it or eat $@
BDIR="build"
BUV_CONF="buv-runbmc"
OLYMPUS_CONF="olympus-nuvoton"
EVB_POLEG_CONF="evb-npcm750"
EVB_ARBEL_CONF="evb-npcm845"


uboot_build()
{
    uboot=`echo $CMD|grep u-boot`
    if [ -n "$uboot" ];then
        UBOOT_BUILD="y"
    fi
}

# automatic choose one configuration for build by current directory
get_conf()
{
if [ -n "$DEFAULT_CONF" ];then
    return
fi
_buv=`echo $(pwd)|grep -i buv`
if [ -n "$_buv" ];then
    DEFAULT_CONF=${BUV_CONF}
    return 0
fi
_runbmc=`echo $(pwd)|grep -ie "runbmc\|olympus"`
if [ -n "$_runbmc" ];then
    DEFAULT_CONF=${OLYMPUS_CONF}
    return 0
fi
_arbel=`echo $(pwd)|grep -i arbel`
if [ -n "$_arbel" ];then
    DEFAULT_CONF=${EVB_ARBEL_CONF}
    return 0
fi
DEFAULT_CONF=${EVB_POLEG_CONF}
}

# show parsed result
dump_var()
{
echo "* * * * * * * * *"
if [ "$DEBUG" == "y" ];then
    echo "Debug mode  : Yes"
fi
echo "Bitbake CMD : ${CMD}"
echo "Bitbake CONF: ${DEFAULT_CONF}"
echo -e "* * * * * * * * *\n"
}

if [ -n "$1" ];then
    TARGET=$@
fi

get_conf
CMD="bitbake ${TARGET}"

dump_var
echo $(date +'%x %X')
if [ ! -f setup ];then
    echo "Cannot find openbmc-env, not correct bitbake folder"
    exit 1
fi
source setup ${DEFAULT_CONF}
if [ "$DEBUG" == "y" ];then
    echo $(pwd)
else
    $CMD
fi
rs=$?
# uboot auto build
uboot_build
if [ "$UBOOT_BUILD" == "y" -a "$rs" == "0" ];then
    echo -e "\nStart U-Boot automatic image build...\n"
    if [ "$DEBUG" != "y" ];then
        bitbake obmc-phosphor-image -C prepare_bootloaders
    fi
fi

echo $(date +'%x %X')
