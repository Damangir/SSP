################################################################################
# ssp - Soheil's Simple Pileline
# Copyright (c) 2016 Soheil Damangir
# GNU General Public License v3 (GPL-3)
# http://github.com/Damangir
################################################################################

if ((BASH_VERSINFO[0] < 3))
then 
  printf "Sorry, you need at least bash-3.0 to run this script.\n" >&2
  exit 1 
fi

if [[ -t 2 ]]
then
    ncolors=$(tput colors)
    if [[ -n "$ncolors" ]] && [[ $ncolors -ge 8 ]]
    then
      SSP_DEFAULT_COLOR="\033[0m"
      SSP_ERROR_COLOR="\033[1;31m"
      SSP_INFO_COLOR="\033[1m"
      SSP_SUCCESS_COLOR="\033[1;32m"
      SSP_WARN_COLOR="\033[1;33m"
      SSP_DEBUG_COLOR="\033[1;34m"
    fi
fi

log() {
    local log_text="$1"
    local log_level="${2:-INFO  }"
    local log_color="${3:-${SSP_INFO_COLOR}}"
    printf "${log_color}[%s] [%s] [${THIS_ID}] %b ${SSP_DEFAULT_COLOR}\n" \
           "$(date +"%Y-%m-%d %H:%M:%S %Z")" "${log_level}" "${log_text}" >&2
}
log_info() { log "$1" "INFO" "${SSP_INFO_COLOR}"; }
log_run() { log "$1" "RUN" "${SSP_DEBUG_COLOR}"; }
log_success() { log "$1" "SUCCESS" "${SSP_SUCCESS_COLOR}"; }
log_error() { log "$1" "ERROR" "${SSP_ERROR_COLOR}";}
log_warning() { log "$1" "WARNING" "${SSP_WARN_COLOR}"; }
log_debug() { log "$1" "DEBUG" "${SSP_DEBUG_COLOR}"; }

error() { printf "${SSP_ERROR_COLOR}%s${SSP_DEFAULT_COLOR}\n" "$*" >&2 ; }
warning() { printf "${SSP_WARN_COLOR}%s${SSP_DEFAULT_COLOR}\n" "$*" >&2 ; }
pjoin()  { local d=$1; shift; printf "$1"; shift; printf "%s" "${@/#/$d}"; }

comment() {
  if [ -z "${DO_NOTHING}" ]
  then
    printf "# %-76s #\n" "$*"
    log_info "$*"
  fi
}
hline() {
  if [ -z "${DO_NOTHING}" ]
  then
    printf "#%.0s" {1..80}
    printf "\n"
  fi
}

trace_stack() {
  set +e
  local frame=${1:-0}
  while caller $frame
  do
    ((frame++))
  done
  set -e
}
date_string() { date +%Y%m%d.%H%M%S%N || date +%Y%m%d.%H%M%S ; }

declare -r START_TIME=$(date_string)

PROCDIR=${PROCDIR:-${1?You should specify PROCDIR or pass it as first var}}
THIS_ID=$(basename ${PROCDIR})

declare -r SCRIPT_NAME=$( basename "${0}" )
declare -r SCRIPT_DIR=$( cd "$( dirname "${0}" )" && pwd )

if [ "$SCRIPT_NAME" = common.sh ]
then
  error "ssp.sh is a utility to be sourced. You can not run it."
  return 1
fi


declare -r STAGE=${SCRIPT_NAME%.*}

hline
comment "SSP - https://github.com/Damangir/SSP"
comment "This is reproduction script."
comment "Please do not modify this file it's for your record"
hline
comment "Begin SSP for $STAGE"

if [ -d $(dirname ${PROCDIR} 2>/dev/null) ]
then
  declare -r PROCDIR=$( cd "$( dirname "${PROCDIR}" )" && pwd )/$(basename "${PROCDIR}")
  comment "PROCDIR: ${PROCDIR}"
  if ! [ -e ${PROCDIR} ]
  then
    comment "Creating ${PROCDIR}"
    mkdir ${PROCDIR}
  fi
else
  error "Directory (${PROCDIR}) does not exist and can not be created"
  exit 1
fi

# Set common directory and files
declare -r LOGDIR=${PROCDIR}/Log
declare -r TOUCHDIR=${PROCDIR}/Touch
declare -r LOCKDIR=${PROCDIR}/Lock
declare -r RERUNDIR=${PROCDIR}/Scripts

declare -r CON_TEMPDIR=${PROCDIR}/Temp

declare -r LOCK_FILE="${LOCKDIR}/processing"
declare -r DONE_FILE="${TOUCHDIR}"/stage.${STAGE}.done
declare -r ERROR_FILE="${TOUCHDIR}"/stage.${STAGE}.error
declare -r STARTED_FILE="${TOUCHDIR}"/stage.${STAGE}.started

if [ -f "${SCRIPT_DIR}/directory_structure.sh" ]
then
  comment "Diredtory structure: ${SCRIPT_DIR}/directory_structure.sh"
  source "${SCRIPT_DIR}/directory_structure.sh"
fi
hline

mkdir -p "${LOGDIR}" "${TOUCHDIR}" "${LOCKDIR}" "${RERUNDIR}"

[ "${DO_NOTHING}" ] && return

printf "PROCDIR=\${PROCDIR:-\${1:-${PROCDIR}}}\n"
printf "[ -d $(dirname ${PROCDIR} 2>/dev/null) ] || exit 1\n"
printf "mkdir -p \${PROCDIR}/%s\n" Log Touch Lock Scripts
printf "cp \$0 \${PROCDIR}/Scripts\n"

[ -f "${SCRIPT_DIR}/directory_structure.sh" ] && cat "${SCRIPT_DIR}/directory_structure.sh"

if [ -e "${LOCK_FILE}" ]
then
  error "${PROCDIR} is locked by another processor. 
Each subject can only be processed by one application at the same time."
  exit 1
fi

on_exit() {
  local rv=$?
  hline
  # Process done without error. Now we check if all req. files is there.
  if [ ${rv} -eq 0 ]
  then
    while IFS= read -r req_f
    do
      if [ "${req_f}" ] && ! [ -e "${req_f}" ]
      then
        error "${req_f} is expected but is not present. I assume the procedure failed."
        rv=1
      fi
    done <<<"$EXPECTED_FILES"
  fi

  if [ ${rv} -ne 0 ]
  then
    log_error "${SCRIPT_NAME} failed on ${PROCDIR}. ERRNO: ${rv}"
    stacktrace=$(trace_stack 1)
    log_debug "Stack trace: \n$stacktrace"
    touch "${ERROR_FILE}"
    # Let's make sure there would be no done file from previous runs.
    rm -f "${DONE_FILE}"
  else
    touch "${DONE_FILE}"
    rm -f "${ERROR_FILE}"
    log_success "${SCRIPT_NAME} succesed on ${PROCDIR}"
  fi
  rm -rf "${STARTED_FILE}"
  rm -rf "${LOCK_FILE}"
  rm -rf "${CON_TEMPDIR}"
  comment "End SSP on $STAGE"
  hline
  printf "\n"
  exit $rv
}

for s in $(printf "%d " {1..31})
do
  trap "exit $s" $s
done

trap on_exit EXIT

(umask 077 && mkdir "${CON_TEMPDIR}") || exit 1

run_and_log() {
  local run_name=$1
  shift

  hline
  comment "Stage ${STAGE}: ${run_name}"
  hline
  (
    env_str=
    while [[ $1 == *"="* ]]
    do
      declare "${1%=*}=${1#*=}"
      export "${1%=*}"
      env_str=$(pjoin " " ${1%=*}=${1#*=} $env_str)
      shift
    done
    if declare -F $1 >/dev/null
    then
      __declare_functions
      printf "(\n"
      __print_var_in_function $1
      printf "%s " "$@"
      printf "\n)"
    else
      printf env
      printf ' "%s"' $env_str "$@"
    fi
    printf "\n"
    log_run "$env_str $*"
    $@ 1>"${LOGDIR}"/log.${STAGE}.${run_name}.stdout 2>"${LOGDIR}"/log.${STAGE}.${run_name}.stderr
  )
  local rv=$?
  if [ "${rv}" -eq 0 ]
  then
    log_success "Success!"
    hline
    printf "\n"
    touch "${TOUCHDIR}/touch.${STAGE}.${run_name}.$(date_string)"
  else
    log_error "Fail!"
    hline
    printf "\n"
    exit $rv
  fi
}

remove_expected_output() {
    while IFS= read -r req_f
    do
      [ -e "${req_f}" ] && rm -r "${req_f}"
    done <<<"$EXPECTED_FILES"
    return 0
}

check_updated() {
  for file in "$@"
  do
    if [ "$file" -nt "${DONE_FILE}" ]
    then
      log_warning "$file has been updated since previous run. I will force the stage to re-run."
      rm -rf "${DONE_FILE}"
    fi
  done
}

check_already_run() {
  [ "${FORCE_RUN}" ] && rm -f "${DONE_FILE}"
  if [ -e "${DONE_FILE}" ]
  then
    warning "Stage ${STAGE} has already been done."
    warning "To force re-run exprot FORCE_RUN=YES or:"
    warning "rm \"${DONE_FILE}\""
    exit 0
  fi
}

depends_on() {
  rv=0
  hline
  for file in "$@"
  do
    comment "Requires: $file"
    if ! [ -f "$file" ]
    then
      log_error "$file is required for running ${SCRIPT_NAME}."
      rv=1
    else
      log_success "$file found!"
    fi
  done
  if [ -e "${DONE_FILE}" ]
  then
    check_updated "$@"
  fi
  hline
  printf "\n"

  return $rv
}

expects() {
  for file in "$@"
  do
    set +e
    read -r -d '' EXPECTED_FILES <<- EOM
${EXPECTED_FILES}
${file}
EOM
  set -e
  done
}

__print_var_in_function(){
    for var in $(declare -f $1 | grep  -o -e '\${#\?[a-zA-Z][^}]*}' -e '\$[a-zA-Z][0-9a-zA-Z_]*' | 
      sed 's/${*#*//g; s/[:[].*//g; s/}//g' | sort -u)
    do
      if ! [ -z ${!var:+x} ]
      then
        (unset $var 2> /dev/null) || continue
        printf "$var=${!var}\n"
      fi

    done
}
__declare_functions() {
  declare -F | sort -u | comm -13 "${CON_TEMPDIR}/old.functions.txt" - >"${CON_TEMPDIR}/to.source.__declare_functions"
  if [ -s "${CON_TEMPDIR}/to.source.__declare_functions" ]
  then
    source "${CON_TEMPDIR}/to.source.__declare_functions"
  fi
  declare -F | sort -u > "${CON_TEMPDIR}/old.functions.txt"
}
declare -F | sort -u > "${CON_TEMPDIR}/old.functions.txt"

rm -f "${TOUCHDIR}"/stage.${STAGE}.error
rm -f "${TOUCHDIR}"/touch.${STAGE}.*

touch "${LOCKDIR}/processing"
touch "${TOUCHDIR}/stage.${STAGE}.started"

printf "\n"

set -e
