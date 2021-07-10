#!/usr/bin/env bash
# ar18

# Prepare script environment
{
  # Script template version 2021-07-10_14:27:20
  # Get old shell option values to restore later
  if [ ! -v ar18_old_shopt_map ]; then
    declare -A -g ar18_old_shopt_map
  fi
  shopt -s inherit_errexit
  ar18_old_shopt_map["$(realpath "${BASH_SOURCE[0]}")"]="$(shopt -op)"
  set +x
  # Set shell options for this script
  set -o pipefail
  set -e
  # Make sure some modification to LD_PRELOAD will not alter the result or outcome in any way
  if [ ! -v ar18_old_ld_preload_map ]; then
    declare -A -g ar18_old_ld_preload_map
  fi
  if [ ! -v LD_PRELOAD ]; then
    LD_PRELOAD=""
  fi
  ar18_old_ld_preload_map["$(realpath "${BASH_SOURCE[0]}")"]="${LD_PRELOAD}"
  LD_PRELOAD=""
  # Save old script_dir variable
  if [ ! -v ar18_old_script_dir_map ]; then
    declare -A -g ar18_old_script_dir_map
  fi
  set +u
  if [ ! -v script_dir ]; then
    script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" &>/dev/null && pwd)"
  fi
  ar18_old_script_dir_map["$(realpath "${BASH_SOURCE[0]}")"]="${script_dir}"
  set -u
  # Save old script_path variable
  if [ ! -v ar18_old_script_path_map ]; then
    declare -A -g ar18_old_script_path_map
  fi
  set +u
  if [ ! -v script_path ]; then
    script_path="${script_dir}/$(basename "${0}")"
  fi
  ar18_old_script_path_map["$(realpath "${BASH_SOURCE[0]}")"]="${script_path}"
  set -u
  # Determine the full path of the directory this script is in
  script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" &>/dev/null && pwd)"
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
  if [ ! -v ar18_exit_map ]; then
    declare -A -g ar18_exit_map
  fi
  ar18_exit_map["${script_path}"]=0
  # Save PWD
  if [ ! -v ar18_pwd_map ]; then
    declare -A -g ar18_pwd_map
  fi
  ar18_pwd_map["$(realpath "${BASH_SOURCE[0]}")"]="${PWD}"
  if [ ! -v ar18_parent_process ]; then
    export ar18_parent_process="$$"
  fi
  # Get import module
  if [ ! -v ar18.script.import ]; then
    mkdir -p "/tmp/${ar18_parent_process}"
    cd "/tmp/${ar18_parent_process}"
    curl -O https://raw.githubusercontent.com/ar18-linux/ar18_lib_bash/master/ar18_lib_bash/script/import.sh > /dev/null 2>&1 && . "/tmp/${ar18_parent_process}/import.sh"
    cd "${ar18_pwd_map["$(realpath "${BASH_SOURCE[0]}")"]}"
  fi
}
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
set +x
function clean_up(){
  rm -rf "/tmp/${ar18_parent_process}"
}
# Restore environment
{
  exit_script_path="${script_path}"
  # Restore script_dir and script_path
  script_dir="${ar18_old_script_dir_map["$(realpath "${BASH_SOURCE[0]}")"]}"
  script_path="${ar18_old_script_path_map["$(realpath "${BASH_SOURCE[0]}")"]}"
  # Restore LD_PRELOAD
  LD_PRELOAD="${ar18_old_ld_preload_map["$(realpath "${BASH_SOURCE[0]}")"]}"
  # Restore PWD
  cd "${ar18_pwd_map["$(realpath "${BASH_SOURCE[0]}")"]}"
  # Restore old shell values
  IFS=$'\n' shell_options=(echo ${ar18_old_shopt_map["$(realpath "${BASH_SOURCE[0]}")"]})
  for option in "${shell_options[@]}"; do
    eval "${option}"
  done
}
# Return or exit depending on whether the script was sourced or not
{
  if [ "${ar18_sourced_map["${exit_script_path}"]}" = "1" ]; then
    return "${ar18_exit_map["${exit_script_path}"]}"
  else
    if [ "${ar18_parent_process}" = "$$" ]; then
      clean_up
    fi
    exit "${ar18_exit_map["${exit_script_path}"]}"
  fi
}

trap clean_up SIGINT
