#!/bin/bash
# ar18

# Script template version 2021-06-12.03
# Make sure some modification to LD_PRELOAD will not alter the result or outcome in any way
LD_PRELOAD_old="${LD_PRELOAD}"
LD_PRELOAD=
# Determine the full path of the directory this script is in
script_dir="$( cd "$( dirname "${BASH_SOURCE[0]}" )" &> /dev/null && pwd )"
script_path="${script_dir}/$(basename "${0}")"
#Set PS4 for easier debugging
export PS4='\e[35m${BASH_SOURCE[0]}:${LINENO}: \e[39m'
# Determine if this script was sourced or is the parent script
if [ ! -v ar18_sourced_map ]; then
  declare -A -g ar18_sourced_map
fi
if [[ "${BASH_SOURCE[0]}" != "${0}" ]]; then
  ar18_sourced_map["${script_path}"]=1
else
  ar18_sourced_map["${script_path}"]=0
fi
# Initialise exit code
if [ -z "${ar18_exit_map+x}" ]; then
  declare -A -g ar18_exit_map
fi
ar18_exit_map["${script_path}"]=0
# Get old shell option values to restore later
shopt -s inherit_errexit
IFS=$'\n' shell_options=($(shopt -op))
# Set shell options for this script
set -o pipefail
set -eu
#################################SCRIPT_START##################################

source="${1}"
source="$(realpath "${source}")"
target="${2}"
target="$(realpath "${target}")"
if [ -d "${target}" ]; then
  echo ""
  read -p "TARGET [${target}] EXISTS"
  exit 1
fi

set +u
gpg_password="${3}"
set -u
if [ "${gpg_password}" = "" ]; then
  echo ""
  read -s -p "enter password: " gpg_password
fi

function do_file(){
  local file
  file="${1}"
  if [[ "${file}" =~ .+\.gpg$ ]]; then
    local target
    target="${2}"
    mkdir -p "${target}"
    local base_name
    base_name="$(basename "${file}")"
    base_name="$(echo "${base_name}" | sed -e 's/\.[^.]*$//')"
    local res
    #echo "${gpg_password}" | gpg -d --batch --yes --passphrase-fd 0 --output "${target}/${base_name}" "${file}"
    res="0"
    echo "${gpg_password}" | gpg --batch --yes --passphrase-fd 0 --output "${target}/${base_name}" "${file}" || res="1"
    echo $res
    if [ "${res}" = "1" ]; then
      cp "${file}" "${target}/$(basename "${file}")"
    fi
  fi
}

function do_dir(){
  local dir
  dir="${1}"
  local target
  target="${2}"
  for filename in "${dir}/"*; do
    if [ -f "${filename}" ]; then
      do_file "${filename}" "${target}"
    elif [ -d "${filename}" ]; then
      do_dir "${filename}" "${target}/$(basename "${filename}")"
    fi
  done
}

if [ -f "${source}" ]; then
  do_file "${source}" "${target}"
elif [ -d "${source}" ]; then
  do_dir "${source}" "${target}"
fi

##################################SCRIPT_END###################################
# Restore old shell values
set +x
for option in "${shell_options[@]}"; do
  eval "${option}"
done
# Restore LD_PRELOAD
LD_PRELOAD="${LD_PRELOAD_old}"
# Return or exit depending on whether the script was sourced or not
if [ "${ar18_sourced_map["${script_path}"]}" = "1" ]; then
  return "${ar18_exit_map["${script_path}"]}"
else
  exit "${ar18_exit_map["${script_path}"]}"
fi
