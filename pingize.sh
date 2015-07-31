#!/bin/bash

function summary {

	echo -e '\n'======summary======='\n'
	# print how many times each return code returned and print the most frequesnt one
	most_key=
	most_value=
	for i in "${!RETURN_CODES[@]}"
	do
		value=${RETURN_CODES[$i]}
		if [[ $most_value < $value ]]
		then 
			most_value=$value
			most_key=$i
		fi
		echo the return code "${i}" was "${RETURN_CODES[$i]}" times
		
	done
	echo -e '\n'the most frequent return code is "${most_key}"
	echo -e '\n'===end of summary===
	exit $1
}

function usage {
	
	echo Usage: pingize.sh [Options] -cmd COMMAND
	echo -e '\t'	-c NUMBER '\t'	the number of times to perform a command
	echo -e '\t' '\t'	'\t'	by default it is 1 time
	echo -e '\t'	-cmd COMMAND '\t'	the command to perform
	echo -e '\t'	-h	'\t' '\t'	print this manual
	echo -e '\t'	--debug '\t'		print each line of the script before it is executed
	exit $1
}

function killed {
	echo -e '\n'------ HEY! You interrupted me -----
	summary 0
}

trap killed SIGINT SIGTERM # SIGINT = ctrl+c, SIGTERM = kill

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
		--debug)
		echo debug flag detected
		set -o xtrace
		;;
		*) # default case
		echo not valid option
		usage 2
		;;
	esac
	shift
		
done
#end of read user parameters

declare -A RETURN_CODES # declare a hash table taht will hold the return codes as keys an return codes as values


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
		return_code=$?
		RETURN_CODES[$return_code]=$(( RETURN_CODES[$return_code] + 1 ))
	done
	
	summary 0
fi
