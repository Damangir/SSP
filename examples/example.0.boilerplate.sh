#!/bin/bash

source "$(cd "$(dirname "$0")"&&pwd)/../ssp.sh"

# Expected input files
# depends_on "${INPUT_1}" "${INPUT_2}" "${INPUT_3}"

# Expected output files
expects	${QCDIR}/It.is.working.txt

expects	${QCDIR}/{1,2,3}.txt
# Check if we need to run this stage
check_already_run
remove_expected_output

my_pid=$$
# More complex tasks can be defined in a function
foo(){
	printf "%s\n" "my_pid=$my_pid" "another=$another"
	printf "%s\n" $@ >>"${QCDIR}/It.is.working.txt"
}

bar(){
	local name=$1
	printf "%s\n" $@ >>"${QCDIR}/$name.txt"
}

# Logs can be done with log_*
log_debug "User running: $(whoami)"


run_and_log 1.command.run printf "Hello\n"

# Comments describing the work can be added
comment "Running some function"
run_and_log 2.command.run.env my_var1=Hello my_var2=Bye env
run_and_log 3.function.run foo this is an example
run_and_log 4.function.run.env another=30 my_pid=100 foo this is an example

run_and_log 5.function.run bar 1 this is an example
run_and_log 6.function.run bar 2 this is another example
run_and_log 7.function.run bar 3 this is yet another example
