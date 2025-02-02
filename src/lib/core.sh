# shellcheck shell=bash

#
# .▄▄ · • ▌ ▄ ·.  ▄▄▄· ▄▄·  ▄▄▄· super
# ▐█ ▀. ·██ ▐███▪▐█ ▄█▐█ ▌▪▐█ ▄█ music
# ▄▀▀▀█▄▐█ ▌▐▌▐█· ██▀·██ ▄▄ ██▀· player
# ▐█▄▪▐███ ██▌▐█▌▐█▪·•▐███▌▐█▪·• client
#  ▀▀▀▀ ▀▀  █▪▀▀▀.▀   ·▀▀▀ .▀    plus+
#
# This file is part of smpcp.
# Copyright (C) 2021-2025, Stéphane MEYER.
#
# Smpcp is free software: you can redistribute it and/or modify
# it under the terms of the GNU General Public License as published by
# the Free Software Foundation, either version 3 of the License, or
# (at your option) any later version.
#
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.
# See the GNU General Public License for more details.
#
# You should have received a copy of the GNU General Public License
# along with this program. If not, see <https://www.gnu.org/licenses/>
#
# CORE
# C │ 2021/03/31
# M │ 2025/01/14
# D │ Utility functions.

# shellcheck disable=SC2034
__version='0.1.9.5'

declare SMPCP_ASSETS="${HOME}/.local/share/smpcp/assets"
declare SMPCP_ICON="${SMPCP_ASSETS}/default.png"
declare SMPCP_CACHE="$HOME/.config/smpcp/.cache"
declare SMPCP_LOG="$HOME/.config/smpcp/log"
declare SMPCP_SETTINGS="$HOME/.config/smpcp/smpcp.conf"

declare SMPCPD_PID="$HOME/.config/smpcp/pid"
declare SMPCPD_LOCK="$HOME/.config/smpcp/lock"

_date() { printf "%($1)T" "${2:--1}"; }

secs_to_hms() {
  # format given duration in seconds to
  # [W week(s),] [D day(s),] [HH:]MM:SS.

  local dur="$1"

  if ((dur>=86400)); then
    local weeks days w d
    ((days=dur/3600/24))
    ((weeks=days/7))

    ((weeks>0)) && ((days=days%7))

    ((weeks>1)) && w="weeks" || w="week"
    ((days>1))   && d="days" || d="day"

    if ((weeks>0)) && ((days>0)); then
      TZ=UTC _date "$((weeks)) ${w}, $((days)) ${d}, %H:%M:%S" $((dur))
    elif ((weeks>0)) && ((days==0)); then
      TZ=UTC _date "$((weeks)) ${w}, %H:%M:%S" $((dur))
    else
      TZ=UTC _date "$((days)) ${d}, %H:%M:%S" $((dur))
    fi

  elif ((dur>=3600)); then
    TZ=UTC _date "%H:%M:%S" $((dur))

  else
    TZ=UTC _date "%M:%S" $((dur))

  fi
}

now() { _date "%F %T"; }

# a simple logger.
logme() {
  [[ $1 == "--clear" ]] && {
    if [[ $(read_config keep_logfiles) == "yes" ]]; then
      [[ -s $SMPCP_LOG ]] && {
        local index=1
        # make a backup copy of log file.
        while [[ -a ${SMPCP_LOG}.${index} ]]; do
          ((index++))
        done
        cp "$SMPCP_LOG" "${SMPCP_LOG}.${index}"
      }
    fi
    :> "$SMPCP_LOG"
    return
  }
  [[ $1 == "--clean" ]] && {
    rm "${SMPCP_LOG}".* &> /dev/null && {
      echo -e "$(now) --- cleaned older log files." >> "$SMPCP_LOG"
      return 0
    }
    return 1
  }

  echo -e "$(now) --- $*" >> "$SMPCP_LOG"
}

# strip path and filename from URI and print lowercase file extension.
get_ext() {
  [[ $1 =~ ^https? ]] && { echo "stream"; return; }
  [[ $1 =~ ^cdda: ]] && { echo "cdda"; return; }
  local ext; ext="${1##*.}"; echo "${ext,,}"
}

max() {
  # return max value
  # usage: 
  #  max <value1> <value2> ... <valueN>
  #  <command> | max

  local v1 v2
  if (( $# > 1 )); then
    for v1 in "$@"; do
      [[ $v1 -gt "$v2" ]] && v2="$v1"
    done
    echo "$v2"
    return 0
  else
    while IFS= read -r v1; do
      [[ $v1 -gt "$v2" ]] && v2="$v1"
    done
    echo "$v2"
    return 0
  fi
  return 1
}

message() {
  # error/message display.

  local _type msg

  case $1 in
    E) _type="error: "; msg="$2" ;;   # error
    M) msg="${2,,}" ;;                # message
    W) _type="warning: "; msg="$2" ;; # warning
  esac

  if [[ $1 == "E" || $1 == "W" ]]; then
    >&2 echo "${_type}${msg}"
  else
    echo "$msg"
  fi
}

read_config() {
  # return setting value for a given parameter.

  [[ $1 ]] || { echo "null"; return 1; }

  [[ -a $SMPCP_SETTINGS ]] || return 1

  local param regex line value
  param="$1"
  regex="^[[:space:]]*${param}[[:space:]]*=[[:space:]]*(.+)$"

  while read -r line; do
    [[ $line =~ ^#.*$ ]] && continue
    [[ $line =~ $regex ]] && {
      if [[ ! ${BASH_REMATCH[1]} ]]; then
        echo "null"
        return 1
      else
        value="${BASH_REMATCH[1]}"
        [[ $value =~ ^\~ ]] &&
          value="${value/\~/"$HOME"}"
        echo "$value"
        return 0
      fi
    }
  done < "$SMPCP_SETTINGS"

  echo "not_found"
  return 1
}

write_config() {
  # write value for a given parameter in config file.
  # append parameter/value to config file if not present.

  [[ -a $SMPCP_SETTINGS ]] || return 1

  [[ -n "$*" && -n "$2" ]] && {
    local param="$1"
    shift
    local value="$*"
    if [[ $(read_config "$param") == "not_found" ]]; then
      echo "$param = $value" >> "$SMPCP_SETTINGS"
    else
      sed -i "s/^\s*${param}\s*.*/${param} = ${value}/" "$SMPCP_SETTINGS"
    fi
  } || return 1
}

remove_config() {
  # remove entry from config file
  local param="$1"
  sed -i "/^\s*${param}\s*.*$/d" "$SMPCP_SETTINGS"
}

check_pid() {
  # check if process is running.
  # usage: check_pid <pid>
  # exit values:
  # 0 if process is active,
  # 1 otherwise.

  local pid="$1"

  [[ $pid ]] || {
    message E "check_pid: missing process id."
    return 1
  }

  kill -0 "$1" 2> /dev/null && return 0 || return 1
}

wait_for_pid() {
  # wait for process to terminate for a given duration.
  # usage: wait_for_pid <duration_in_seconds> <pid>
  # exit values:
  # 0 if process ended,
  # 1 otherwise.

  local dur pid count
  dur="$1"
  pid="$2"
  count=0

  [[ $dur && $pid ]] && {
    while ((count<dur)); do
      check_pid "$pid" 2> /dev/null || return 0
      sleep 1
      ((count++))
    done
    check_pid "$pid" 2> /dev/null && return 1 || return 0
  }
}

is_daemon() {
  # check whether daemon is running.
  [[ -a $SMPCPD_PID ]] || return 1

  local pid
  pid="$(<"$SMPCPD_PID")"

  check_pid "$pid" 2> /dev/null
}

update_daemon() {
  # send HUP signal to daemon to notify it
  # to add new songs to the queue.

  local pid
  pid="$(<"$SMPCPD_PID")"
  kill -HUP "$pid" 2> /dev/null
}
