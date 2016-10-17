#!/bin/bash

set -e

# export input variables:
export PROCDIR=$1

# run each stage:
SRC_DIR="$(cd "$(dirname "$0")"&&pwd)"

# Just create directories
DO_NOTHING=YES source ${SRC_DIR}/../ssp.sh

# stdoutput would be all commands to be run to recreate the run
${SRC_DIR}/example.0.boilerplate.sh 1>${RERUNDIR}/pipeline.${START_TIME}.sh
