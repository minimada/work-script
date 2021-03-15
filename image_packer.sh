#!/bin/bash
#
#
# 

Usage(){
	echo `basename $0` "[-vpjmd data]"
	echo "  -v: set backup image name (version)"
	echo "  -p: set project name"
	echo "  -j: set project name in Jenkins"
	echo "  -m: set machine name"
	echo "  -d: set backup folder name"
	exit 1
}

export DL_CACHE_HOME=/home/cs20
export BACKUP_PATH=${DL_CACHE_HOME}/images_backup
# Jenkins project
JPROJECT=Nuvoton-OpenBMC
# the build project setting in build project Configuration Matrix
PROJECT=olympus-nuvoton
# the machine name define in source code conf folder
MACHINE="" # default set to project
# /var/jenkins_home/workspace/Nuvoton-OpenBMC/target/olympus-nuvoton/deploy/images/olympus-nuvoton
IMAGE_SOURCE=${WORKSPACE}/${JPROJECT}/target/${PROJECT}/deploy/images/${MACHINE}
# full image, signle image for each partition, vmlinux
COLEECTION="vmlinux* *-image-*static.mtd.*"
VERSION="Default version"

parse_arg(){
	while getopts ":v:p:m:d:j:" argv;do
		case "$argv" in
			p)
				PROJECT=${OPTARG}
				;;
			d)
				BACKUP_PATH=${DL_CACHE_HOME}/${OPTARG}
				;;
			j)
				JPROJECT=${OPTARG}
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
	if [ -z "${PROJECT}" ];then
		echo "Project cannot empty"
		Uasge
	fi

	# for debug use, test script in non-jenkins environment
	user=`id -un`
	if [ "${user}" != "jenkins" ];then
		WORKSPACE="/var/jenkins_home/workspace"
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
		MACHINE=${PROJECT}
	fi

	IMAGE_SOURCE=${WORKSPACE}/${JPROJECT}/target/${PROJECT}/deploy/images/${MACHINE}
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