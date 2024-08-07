#!/bin/bash

# ***********************************************
#  Info : build script for Nuvoton openbmc project
#
#  Usage:
#       qbuild
#       qbuild [target] [option]
#  Example:
#       CONF=buv-runbmc DEBUG=y qbuild # force run buv-runbmc, and only generate conf
#       CONF=buv-runbmc CCONF=y qbuild # keep local.conf and re-generate other conf
#                                        this is used for bblayer change due to
#                                        openbmc upgrade
#       CCONF=buv-runbmc qbuild # same funtion as above option, for lazy man
#
# ***********************************************

# parameters
UBOOT_BUILD="n"
TARGET="obmc-phosphor-image"
DEFAULT_CONF=${CONF:=""}
DEBUG=${DEBUG:="n"}

# fixed parameters
# oe-buildenv-internal will get BDIR from $2, we need to set it or eat $@
#BDIR="build"
BUV_CONF="buv-runbmc"
OLYMPUS_CONF="olympus-nuvoton"
EVB_POLEG_CONF="evb-npcm750"
EVB_ARBEL_CONF="evb-npcm845"


uboot_build()
{
    uboot=$(echo "${CMD}"|grep u-boot)
    if [ -n "$uboot" ];then
        UBOOT_BUILD="y"
    fi
}

# automatic choose one configuration for build by current directory
get_conf()
{
if [ -n "${DEFAULT_CONF}" ];then
    return
fi
# lazy user want to type lesser key, CCONF=y CONF=xxx=> CCONF=xxx
if [ -n "${CCONF}" ];then
    if [ "${CCONF}" != "y" ]; then
        DEFAULT_CONF=${CCONF}
        return
    fi
fi

_buv=$(pwd | grep -i buv)
if [ -n "$_buv" ];then
    DEFAULT_CONF=${BUV_CONF}
    return 0
fi
_runbmc=$(pwd | grep -ie "runbmc\|olympus")
if [ -n "$_runbmc" ];then
    DEFAULT_CONF=${OLYMPUS_CONF}
    return 0
fi
_arbel=$( pwd | grep -i arbel)
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
if [ "${DEBUG}" == "y" ];then
    echo "Debug mode  : Yes"
fi
if [ -n "${CCONF}" ];then
    echo "Clean conf  : Yes"
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

# specail case for bblayer change, keep local.conf and re-generate conf folder
if [ -n "${CCONF}" ];then
    CLEAN_CONF="y"
    temp_conf=$(mktemp -u)
    cp "build/${DEFAULT_CONF}/conf/local.conf" "${temp_conf}"
    rm -r "build/${DEFAULT_CONF}/conf/"
fi

dump_var
date +'%x %X'
if [ ! -f setup ];then
    echo "Cannot find openbmc-env, not correct bitbake folder"
    exit 1
fi
set -e
source setup ${DEFAULT_CONF}
if [ "${CLEAN_CONF}" == "y" ]; then
    # we are now at build folder
    cp -v "${temp_conf}" "conf/local.conf"
    rm "${temp_conf}"
fi
set +e
if [ "${DEBUG}" == "y" ];then
    pwd
else
    $CMD
fi
rs=$?
# uboot auto build, we don't need this anymore after once IGPS
#uboot_build
#if [ "${UBOOT_BUILD}" == "y" ] && [ "${rs}" == "0" ];then
#    echo -e "\nStart U-Boot automatic image build...\n"
#    if [ "${DEBUG}" != "y" ];then
#        bitbake obmc-phosphor-image -C prepare_bootloaders
#    fi
#fi

date +'%x %X'
exit "$rs"
