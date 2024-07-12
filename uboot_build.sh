#!/bin/bash

# ***********************************************
#  Info : build script for U-Boot release
#
#  Usage:
#       uboot_build.sh
#       BRANCH=npcm-v2021.04 CC=/tmp/bin/aarch64-none-linux-gnu- uboot_build.sh
#
# ***********************************************
#
# U-Boot release build
#
# 1. Build u-boot.bin locally
# make arbel_evb_defconfig
# make CROSS_COMPILE=~/bin/aarch64-linux-gnu/bin/aarch64-none-linux-gnu- -j4
#
# 2. Create a git tag
# Example:
# git tag -a v2023.10-npcm8xx-20240711
# git push origin v2023.10-npcm8xx-20240711 
#
# 3. Relase u-boot.bin in https://github.com/Nuvoton-Israel/u-boot/releases 
#
# Draft a new release -> Choose a tag -> Describe this release -> 
#   Upload u-boot.bin(Attach binaries by dropping them here or selecting them) -> 
#   Publish release
# 

# parameter
DEFCONFIG=${DEFCONFIG:="arbel_evb_defconfig"}
BRANCH=${BRANCH:="npcm-v2023.10"}
REMOTE=${REMOTE:="origin"}
CC=${CC:="${HOME}/bin/aarch64-linux-gnu/bin/aarch64-none-linux-gnu-"}
JOBS=${JOBS:="16"}
PATCH=${PATCH:=""}

set -ex
# check environment
"${CC}gcc" --version
PRE_TAG=$(git describe --abbrev=0) # like v2023.10-npcm8xx-20240411
if [ "${PRE_TAG}" = "$(git describe)" ]; then
  echo "ERROR: there is no change from last release."
  exit 1
fi

# clean up codebase
git fetch "${REMOTE}"
git reset --hard "${REMOTE}/${BRANCH}"
make clean

# apply patch if need
if [ -n "${PATCH}" ]; then
  git apply "${PATCH}"
fi

# build config
make "${DEFCONFIG}"

# build u-boot
make "CROSS_COMPILE=${CC}" "-j${JOBS}"

# git tag
TAG_H=$(echo $BRANCH |grep -o "v20.*")
TAG="${TAG_H}-npcm8xx-$(date +%Y%m%d)"
git tag -a "${TAG}" -m "add release tag:${TAG}"
git push "${REMOTE}" "${TAG}"

# release note
echo "Change log:"
git shortlog "${PRE_TAG}..HEAD"

# github release
# ref: https://cli.github.com/manual/gh_release_create
# chech gh command exist
which gh
# may need login first: 
#gh auth login
# select push repo --repo=Nuvoton-Israel/u-boot
gh release create "${TAG}" --generate-notes -d u-boot.bin


# remove tag hint!
# remove local tag:
#    git tag -d [tag]
#    git tag -d v2023.10-npcm8xx-20240712
# remove remote tag:
#    git push --delete [remote] [tag]
#    git push --delete mada v2023.10-npcm8xx-20240712