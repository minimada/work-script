#!/bin/bash
#
#
# 

Usage(){
	echo `basename $0` "[-vmd data]"
	echo "  -v: set backup image name (version)"
	echo "  -m: set machine name"
	echo "  -d: set backup folder name"
	exit 1
}

export BACKUP_PATH=${DL_CACHE_HOME}/images_backup

# the machine name define in source code conf folder
MACHINE="" # default set to project
# /var/jenkins_home/workspace/Nuvoton-OpenBMC/target/olympus-nuvoton/deploy/images/olympus-nuvoton
IMAGE_SOURCE=${WORKSPACE}/deploy/images/${MACHINE}
# full image, signle image for each partition, vmlinux
COLEECTION="vmlinux* *-image-*static.mtd.*"
VERSION="Default version"

parse_arg(){
	while getopts ":v:m:d:" argv;do
		case "$argv" in
			d)
				BACKUP_PATH=${DL_CACHE_HOME}/${OPTARG}
				;;
			m)
				MACHINE=${OPTARG}
				;;
			v)
				VER=${OPTARG}
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
		BACKUP_PATH=${DL_CACHE_HOME}/$(basename ${BACKUP_PATH})
	fi

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

	if [ ! -d "$IMAGE_SOURCE" ];then
		echo "Cannot find image source folder: ${IMAGE_SOURCE}"
		exit 1
	fi
}

get_backup_target(){
	for p in $COLEECTION
	do
		find -H . -name "$p" -type f
	done
}

zip_files(){
	tar -cjf images.tar.bz2 $1
	mv -v images.tar.bz2 ${BACKUP_PATH}/${VERSION}.tar.bz2
	if [ "$?" != "0" ];then
		exit 1
	fi
}


# Main
parse_arg $@

cd $IMAGE_SOURCE
files=`get_backup_target`
if [ -z "$files" ];then
	echo " cannot find target file for backup"
	exit 1
fi
echo $files

zip_files $files
cd $OLDPWD

exit 0
