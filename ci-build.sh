#!/bin/bash -xe
#
# Purpose:
#  This script is responsible for setting up a openbmc/openbmc build
#  environment for a meta-* repository.
#
# Required Inputs:
#  WORKSPACE:       Directory which contains the extracted meta-*
#                   layer test is running against
#  GERRIT_PROJECT : openbmc/meta-* layer under test (i.e. openbmc/meta-phosphor)
#  GERRIT_BRANCH  : Branch under test (default is master)
#  GERRIT_REFSPEC : the gerrit change which trigger build, if empty, just perform build test

#
#  NOTE
#
#    docker image: openbmc/ubuntu:latest-olympus-nuvoton-x86_64 must exit
#        this image is build from build-setup.sh
#
#    META_REPO must clean up every build test
#

export LANG=en_US.UTF8
cd $WORKSPACE

GERRIT_BRANCH=${GERRIT_BRANCH:-"master"}
GERRIT_PROJECT=${GERRIT_PROJECT:-"openbmc/meta-nuvoton"}
GERRIT_USER=Jenkins-openbmc-nuvoton
GERRIT_HOST=${GERRIT_HOST:-"gerrit.openbmc-project.xyz"}


build_project(){
  docker run \
  --cap-add=sys_admin \
  --cap-add=sys_nice \
  --net=host \
  --rm=true \
  -e WORKSPACE=${WORKSPACE} \
  -w "${HOME}" \
  -v "${HOME}":"${HOME}" \
  -t ${img_name} \
  ${WORKSPACE}/build.sh ${1}
}


echo "Triggered by ${GERRIT_PROJECT}"

export META_REPO=`basename $GERRIT_PROJECT`

# Move the extracted meta layer to a dir based on it's meta-* name
#mv $GERRIT_PROJECT $META_REPO

# Remove openbmc dir in prep for full repo clone
# for save build PC resource, ignore remove all data
#rm -rf openbmc
cd ${WORKSPACE}/openbmc
git fetch origin
git reset --hard origin/master

# fetch change and patch it!
# we don't need to check this repo, jenkins pull newest code.
cd ${WORKSPACE}/${META_REPO}

# only perform patch when trigger by gerrit
if [ -n "${GERRIT_REFSPEC}" ];then
  git fetch "ssh://${GERRIT_USER}@${GERRIT_HOST}:29418/${GERRIT_PROJECT}" ${GERRIT_REFSPEC} && git checkout FETCH_HEAD
else
  echo "perform build project test only"
fi

cd $WORKSPACE

# Clone openbmc/openbmc
#git clone https://github.com/openbmc/openbmc.git --branch ${GERRIT_BRANCH} --single-branch

# Make sure meta-* directory is there
mkdir -p ./openbmc/$META_REPO/

# Clean out the dir to handle delete/rename of files
rm -rf ./openbmc/$META_REPO/*

# Copy the extracted meta code into it
cp -Rf $META_REPO/* ./openbmc/$META_REPO/


# === ENV setup ===

# make sure build environment docker exist
docker image ls openbmc/ubuntu |grep olympus-nuvoton
img_name=openbmc/ubuntu:latest-olympus-nuvoton-x86_64

# prepare build script

cat > "${WORKSPACE}"/build.sh << 'EOF_SCRIPT'
#!/bin/bash

set -eo pipefail

pp=$(basename $1)
echo "build project ${1}"

cd ${WORKSPACE}/openbmc

export BDIR="build"
# Source our build env
TEMPLATECONF=${1}/conf source oe-init-build-env

# Custom BitBake config settings
cat >> conf/local.conf << EOF_CONF
BB_NUMBER_THREADS = "4"
PARALLEL_MAKE = "-j4"
INHERIT += "rm_work"
BB_GENERATE_MIRROR_TARBALLS = "1"
DL_DIR="/var/jenkins_home/bitbake_downloads"
SSTATE_DIR="/var/jenkins_home/bitbake_sharedstatecache"
USER_CLASSES += "buildstats"
INHERIT_remove = "uninative"
TMPDIR="/tmp/openbmc"
EOF_CONF

# Kick off a build
bitbake obmc-phosphor-image

echo "project ${1} build finished."
EOF_SCRIPT

chmod a+x "${WORKSPACE}"/build.sh


# Create a dummy commit so code update will pick it up
cd openbmc 

git add -A && git commit --allow-empty -m "Dummy commit to cause code update"


# trigger build for meta-nuvoton on master branch
build_project meta-quanta/meta-olympus-nuvoton


# restore meta repo for next clean build
cd ${WORKSPACE}/
rm -rf ./openbmc/$META_REPO/*
cd openbmc
git reset --hard origin/runbmc
rm -rf build/conf/*
