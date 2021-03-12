#!/bin/bash
#
#
# 

Usage(){
    echo `basename $0` "[-ijlm data]"
    echo "      -i : set data as image path"
    echo "      -j : set data as image max"
    echo "      -l : set data as log path"
    echo "      -m : set data as log max"
    exit 1
}

# Definitions
LOG_MAX=30
IMAGE_MAX=30
LOG_PATH=/home2/cs20/test_logs
IMAGE_PATH=/home2/cs20/images_backup

# functions
# need direct set globle var or use local 
get_image_count(){
	find $IMAGE_PATH -maxdepth 1 -type f | wc -l
}

get_log_count(){
	find $LOG_PATH -maxdepth 1 -mindepth 1 -type d | wc -l
}

# $1 : log or image path
# $2 : max count
# $3 : run log or image
rotate(){
	if [ ! -d "$1" ];then
		echo "cannot find path: $1"
		return
	else
		local path="$1"
		local max="$2"
	fi

	if [ "$verbose" == "y" ];then
		echo "Type: $3"
		echo "Path: $path"
		echo "Max : $max"
	fi	

	if [ "$3" == "LOG" ];then
		local count=$(get_log_count)
	elif [ "$3" == "IMAGE" ];then
		local count=$(get_image_count)
	else
		echo "invalid type"
		return
	fi

	if [ "$count" -gt "$max" ];then
		diff=$(expr $count - $max)
		rm_set=$(ls $path | tr "\[ \]*" "\n" | head -n $diff)
		if [ "$verbose" == "y" ];then
			echo "Trying to remove..."
			echo $rm_set
		fi
		if [ "$not_remove" != "n" ];then
			cd $path
			rm -rv $rm_set
		fi
	fi

}

parse_arg(){
	while getopts ":vdni:j:l:m:" argv;do
		case "$argv" in
			i)
				IMAGE_PATH=${OPTARG}
				;;
			j)
				IMAGE_MAX=${OPTARG}
				;;
			l)
				LOG_PATH=${OPTARG}
				;;
			m)
				LOG_MAX=${OPTARG}
				;;
			v)
				verbose="y"
				;;
			n)
				not_remove="n"
				;;
			d)
				verbose="y"
				not_remove="n"
				;;
			*)
				Usage
				;;
		esac
	done
	shift $((OPTIND-1))
}

# Main
parse_arg $@

rotate $LOG_PATH $LOG_MAX "LOG"

rotate $IMAGE_PATH $IMAGE_MAX "IMAGE"

exit 0
