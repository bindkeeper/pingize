#!/bin/bash

function usage {
	echo Usage: pingize.sh [Options] -cmd COMMAND
	echo -e '\t'	-c NUMBER '\t'	the number of times to perform a command
	echo -e '\t' '\t'	'\t'	by default it is 1 time
	echo -e '\t'	-cmd COMMAND '\t'	the command to perform
	echo -e '\t'	-h	'\t' '\t'	print this manual
	exit $1
}

#global variables that holds user input
COUNT=
CMD=

# read user parameters
while [[ $# > 0 ]] # travers on all parameters supplied to the script
do
	case $1 in
		-c)
		COUNT="$2"
		shift
		;;
		-cmd)
		CMD="$2"
		shift
		;;
		-h)
		usage 0
		;;
		*) # default case
		echo not vald option
		usage 2
		;;
	esac
	shift
		
done
#end of read user parameters

if [[ -z $CMD ]]
then
	echo please supply command
	usage 2
else
	echo the command is "${CMD}"
	if [[ -z $COUNT ]] # in case the user did not supplied a count to work with
	then
		my_count=1
	else
		my_count=$COUNT
	fi
	while [[ $my_count > 0 ]]
	do
		((my_count--))
		eval $CMD
	done

fi
