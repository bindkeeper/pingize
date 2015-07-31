#!/bin/bash

function summary {

	echo -e '\n'======summary======='\n'
	# print how many times each return code returned and print the most frequesnt one
	most_key=
	most_value=
	for i in "${!RETURN_CODES[@]}"
	do
		value=${RETURN_CODES[$i]}
		if [[ $most_value -lt $value ]]
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
	echo -e '\t'	--failed-count N'\t'	N is the number of allowed failed
	echo -e '\t\t\t\t' command invocation attempts before stopping the script
	echo -e '\t'	--net-trace '\t'	will create a pcap file for every failed execution
	echo -e '\t\t\t' the names of the file will be [failed attempt number].pcap
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
N_COUNT=
NET_TRACE=

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
		--failed-count)
		N_COUNT="$2"
		shift
		;;
		--net-trace)
		hash tcpdump 2>/dev/null # check that tcpdump is installed
		if [[ $? -ne 0 ]]
		then
			echo tcpdump is required but not installed
			exit 2
		fi
		NET_TRACE=1
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
		my_count=$COUNT # the number of executions
	fi
	my_n_count=0 # count the number of failed executions

	# this while will run $my_count times
	# will stop after $N_COUNT failures (return code is not 0)
	while [[ ( $my_count > 0 ) && ( ( -z $N_COUNT ) || ( $N_COUNT > $my_n_count ) ) ]]
	do
		((my_count--))
		return_code=
		if [[ $NET_TRACE ]]
		then
			tcpdump -w temp.pcap > /dev/null 2>&1 &
			tcp_dump_pid=$!
			sleep 1
			eval $CMD
			return_code=$?
			sleep 1
			kill $tcp_dump_pid
		else
			eval $CMD
			return_code=$?
		fi

		if [[ ( ( $N_COUNT ) && ( $return_code -ne 0 ) ) || ( $NET_TRACE ) ]]
		then 
			((my_n_count++))
		fi

		if [[ $NET_TRACE ]]
		then
			
			if [[ $return_code -eq 0 ]]
			then
				echo need to remove temp.pcap
				# need to remove temp.pcap
				rm ./temp.pcap
			else
				echo renaming temp.pcap
				# we need to rename the temp.pcap
				mv temp.pcap "${my_n_count}".pcap
			fi
		fi

		RETURN_CODES[$return_code]=$(( RETURN_CODES[$return_code] + 1 ))
	done
	
	summary 0
fi
