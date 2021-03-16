#!/bin/bash
#
# test command: -l /home2/cs20/test_logs -i /home2/cs20/images_backup -f buv-runbmc:olympus-nuvoton
# 

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
LOG_MAX=30
IMAGE_MAX=30
# use /home2 for debug environment
LOG_PATH=/home/cs20/test_logs
IMAGE_PATH=/home/cs20/images_backup

# functions
# need direct set globle var or use local 
get_image_count(){
	find $1 -maxdepth 1 -type f | wc -l
}

get_log_count(){
	find $1 -maxdepth 1 -mindepth 1 -type d | wc -l
}

# $1 : log or image path
# $2 : max count
# $3 : run log or image
# $4 : filter for handler each project
rotate(){
	if [ ! -d "${1}/${4}" ];then
		echo "cannot find path: ${1}/${4}"
		return
	else
		local path="${1}/${4}"
		local max="$2"
	fi

	if [ "$verbose" == "y" ];then
		echo " "
		echo "Type  : $3"
		echo "Path  : $path"
		echo "Max   : $max"
		echo "Filter: $4"
	fi	

	if [ "$3" == "LOG" ];then
		local count=$(get_log_count ${path})
	elif [ "$3" == "IMAGE" ];then
		local count=$(get_image_count ${path})
	else
		echo "invalid type"
		return
	fi

	if [ "$verbose" == "y" ];then
		echo "Count : $count"
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
	while getopts ":vdni:j:l:m:f:" argv;do
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
				debug="y"
				;;
			f)
				# like Buv:Olympus
				IMAGE_FILTERS=${OPTARG}
				;;
			*)
				Usage
				;;
		esac
	done
	shift $((OPTIND-1))
	IMAGE_FILTERS=`echo $IMAGE_FILTERS | tr ":" " "`
	if [ "$debug" == "y" ];then
		echo "FILTERS: $IMAGE_FILTERS"
	fi
}

# Main
parse_arg $@

for filter in $IMAGE_FILTERS
do
	rotate $LOG_PATH $LOG_MAX "LOG" $filter

	rotate $IMAGE_PATH $IMAGE_MAX "IMAGE" $filter
done

exit 0
