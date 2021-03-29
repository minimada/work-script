#!/bin/bash
#
# $0 -m buv-runbmc -v BUV.runbmc.0.01.00a-dunfell -d images_backup/buv-runbmc
# 

Usage(){
	echo `basename $0` "[-vmd data]"
	echo "  -v: set backup image name (version)"
	echo "  -m: set machine name"
	echo "  -d: set backup folder name with filter"
	exit 1
}

DL_CACHE_HOME=${DL_CACHE_HOME:-/home/cs20}

# the machine name define in source code conf folder
MACHINE="" # default set to project
# /var/jenkins_home/workspace/Nuvoton-OpenBMC/target/olympus-nuvoton/deploy/images/olympus-nuvoton
IMAGE_SOURCE=${WORKSPACE}/deploy/images/${MACHINE}
CODE_SOURCE=""
# full image, signle image for each partition, vmlinux
COLEECTION="vmlinux* *-image-*static.mtd.*"
VERSION="Default version"

get_git_version(){
	cd $CODE_SOURCE
	GIT_VER=`git describe`
	cd $OLDPWD
}

parse_arg(){
	while getopts ":v:m:d:t" argv;do
		case "$argv" in
			d)
				BACKUP_PATH=${OPTARG}
				;;
			m)
				MACHINE=${OPTARG}
				;;
			v)
				VER=${OPTARG}
				;;
			t)
				DEV_MODE=1
				;;
			*)
				Usage
				;;
		esac
	done
	shift $((OPTIND-1))
	if [ -z "$VER" ];then
		echo "Must set version"
		Usage
	else
		VERSION=$VER
	fi

	# for debug use, test script in non-jenkins environment
	user=`id -un`
	if [ "${user}" != "jenkins" ];then
		WORKSPACE="/var/jenkins_home/workspace/BUV-build/target/buv-runbmc"
		DL_CACHE_HOME="/home2/cs20"
	fi
	BACKUP_PATH=${DL_CACHE_HOME}/${BACKUP_PATH}
	CODE_SOURCE=${WORKSPACE}/openbmc

	if [ ! -d "$BACKUP_PATH" ];then
		echo "Backup destination must exist! $BACKUP_PATH"
		Usage
	fi
	if [ -f "${BACKUP_PATH}/${VERSION}.tar.bz2" ];then
		echo "target backup image file exist, please check input parameter!"
		echo "file: ${BACKUP_PATH}/${VERSION}.tar.bz2"
		exit 1
	fi
	if [ -z "$MACHINE" ];then
		echo "Must set machine name"
		Usage
	fi

	IMAGE_SOURCE=${WORKSPACE}/deploy/images/${MACHINE}
	COLEECTION="vmlinux* *-${MACHINE}-*.static.mtd.*"

	if [ ! -d "$IMAGE_SOURCE" ];then
		echo "Cannot find image source folder: ${IMAGE_SOURCE}"
		exit 1
	fi

	if [ -d "$CODE_SOURCE" ];then
		get_git_version
	else
		echo "Cannot get git version!"
		GIT_VER="none"
	fi
}

get_backup_target(){
	for p in $COLEECTION
	do
		find -H . -name "$p" -type f
	done
}

clean_file_path(){
	local fl=""
	for f in $files
	do
		fl+=" $(basename $f)"
	done
	files="$fl"
}

zip_files(){
	if [ "${DEV_MODE}" == "1" ];then
		echo "pwd: $PWD"
		echo "touch $VERSION-$GIT_VER"
		echo "tar -cjf images.tar.bz2 $@ $VERSION-$GIT_VER"
		echo "mv -v images.tar.bz2 ${BACKUP_PATH}/${VERSION}.tar.bz2"
		return
	fi
	touch $VERSION-$GIT_VER
	tar -cjf images.tar.bz2 $@ $VERSION-$GIT_VER
	mv -v images.tar.bz2 ${BACKUP_PATH}/${VERSION}.tar.bz2
	if [ "$?" != "0" ];then
		exit 1
	fi
}


# Main
parse_arg $@

cd $IMAGE_SOURCE
files=`get_backup_target`
if [ "${DEV_MODE}" == "1" ];then
	echo "files: $files"
	echo "COLEECTION: $COLEECTION"
fi
clean_file_path
if [ -z "$files" ];then
	echo " cannot find target file for backup"
	exit 1
fi
echo "backup files: $files"

zip_files $files
cd $OLDPWD

echo "image backup finished $(date)"
exit 0
