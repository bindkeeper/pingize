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
	echo -e '\t'	--sys-trace '\t'	will create four log files for every failed execution
	echo -e '\t\t\t' the names of the files will be:
	echo -e	'\t\t\t' [failed attempt number].io will hold the disk i\o information
	echo -e	'\t\t\t' [failed attempt number].cpu will hold the cpu information and number of thread detected
	echo -e	'\t\t\t' [failed attempt number].statm will hold the memory information
	echo -e	'\t\t\t' [failed attempt number].net will hold the printouts of ifconfig -s

	exit $1
}

function sys_trace_clean {

	if [[ -e temp.io ]] ; then rm ./temp.io; fi
	if [[ -e temp.statm ]] ; then rm ./temp.statm; fi
	if [[ -e temp.cpu ]] ; then rm ./temp.cpu; fi
	if [[ -e temp.net ]] ; then rm ./temp.net; fi
}

function sys_loging {
	echo ====== `date` ===== >> temp.io
	cat /proc/"${cmd_pid}"/io >> temp.io
	echo =================end==================== >> temp.io

	
	echo ====== `date` ===== >> temp.statm
	awk ' {printf "size\t\t%s\nresident\t%s\nshare\t\t%s\ntext\t\t%s\nlib\t\t%s\ndata\t\t%s\ndt\t\t%s\n", $1, $2, $3, $4, $5, $6, $7} ' /proc/"${cmd_pid}"/statm >> temp.statm
	echo =================end==================== >> temp.statm

	echo ====== `date` ===== >> temp.cpu
	awk ' {printf "user mod cpu time (utime)\t%s\nkernel mod cpu time (stime)\t%s\nThreads\t\t\t\t%s\n", $14, $15, $20} ' /proc/"${cmd_pid}"/stat >> temp.cpu
	echo =================end==================== >> temp.cpu

	
	echo ====== `date` ===== >> temp.net
	ifconfig -s >> temp.net
	echo =================end==================== >> temp.net

}

function run_command {
	if [[ $SYS_TRACE ]]
	then
		sys_trace_clean
		eval " ( $CMD ) & "
		cmd_pid=$!
		echo the cmd_pid is "${cmd_pid}"
		while (( 1 ))
		do 
			kill -SIGSTOP $cmd_pid # pause the command
		
			sys_loging

			kill -SIGCONT $cmd_pid # resumes the command
			sleep 0.1
			ps -ef | awk ' { print $2 } ' | grep $cmd_pid > /dev/null 2>&1 # search for the command process
			if [[ $? -ne 0 ]]
			then
				# the command process not found so we stop the loop
				break
			fi
		done

		wait $cmd_pid # catching the return code of the command
		return_code=$?

	else
		eval $CMD
		return_code=$?
	fi
}

function killed {
	echo -e '\n'------ HEY! You interrupted me -----
	if [[ $SYS_TRACE ]]
	then
		sys_trace_clean
	fi
	summary 0
}

trap killed SIGINT SIGTERM # SIGINT = ctrl+c, SIGTERM = kill

#global variables that holds user input
COUNT=
CMD=
N_COUNT=
NET_TRACE=
SYS_TRACE=

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
		--sys-trace)
		SYS_TRACE=1
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
			run_command
			sleep 1
			kill $tcp_dump_pid
		else
			run_command
		fi

		if [[ ( ( $N_COUNT ) && ( $return_code -ne 0 ) ) || ( $NET_TRACE ) || ( $SYS_TRACE ) ]]
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
		
		if [[ $SYS_TRACE ]]
		then
			if [[ $return_code -ne 0 ]]
			then
				mv temp.io "${my_n_count}".io
				mv temp.statm "${my_n_count}".statm
				mv temp.cpu "${my_n_count}".cpu
				mv temp.net "${my_n_count}".net
			else
				rm temp.io
				rm temp.statm
				rm temp.cpu
				rm temp.net
			fi	
		fi

		RETURN_CODES[$return_code]=$(( RETURN_CODES[$return_code] + 1 ))
	done
	
	summary 0
fi
