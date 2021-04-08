#! /usr/bin/env bash

#
# .▄▄ · • ▌ ▄ ·.  ▄▄▄· ▄▄·  ▄▄▄· simple
# ▐█ ▀. ·██ ▐███▪▐█ ▄█▐█ ▌▪▐█ ▄█ music
# ▄▀▀▀█▄▐█ ▌▐▌▐█· ██▀·██ ▄▄ ██▀· player
# ▐█▄▪▐███ ██▌▐█▌▐█▪·•▐███▌▐█▪·• client
#  ▀▀▀▀ ▀▀  █▪▀▀▀.▀   ·▀▀▀ .▀    plus+
#
# This file is part of smpcp.
# Copyright (C) 2021, Stéphane MEYER.
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
# M │ 2021/04/06
# D │ Utility functions.

# shellcheck disable=SC2034
__version='0.1'

declare SMPCP_SETTINGS="$HOME/.config/smpcp/settings"
declare SMPCP_HIST="$HOME/.config/smpcp/history"
declare SMPCP_LOG="$HOME/.config/smpcp/log"
declare STICKER_DB="$HOME/.config/mpd/sticker.sql"
declare SMPCP_LOCK="$HOME/.config/smpcp/lock"

_date() { printf "(%$1)T" "-1"; }

now() { _date "%F %T"; }

# a simple logger.
logme() { echo "$(now) --- $*" >> "$SMPCP_LOG"; }

__msg() {
  # error/message display.
  local _type
  case $1 in
    E) _type="!! "; shift ;; # error
    M) _type=":: "; shift ;; # message
    W) _type="-- "; shift ;; # warning
  esac
  >&2 echo "[smpcp] ${_type}$1"
}

read_config() {
  # return setting value for a given parameter.

  [[ $1 ]] || { echo "null"; return 1; }
  
  local param regex line
  param="$1"
  regex="^[[:space:]]*${param}[[:space:]]*=[[:space:]]*(.+)$"

  while read -r line; do
    [[ $line =~ ^#.*$ ]] && continue
    [[ $line =~ $regex ]] && {
      if [[ ! ${BASH_REMATCH[1]} ]]; then
        echo "null"
        return 1
      else
        echo "${BASH_REMATCH[1]}"
        return 0
      fi
    }
  done < "$SMPCP_SETTINGS"

  echo "not_found"
  return 1
}

write_config() {
  # write value for a given parameter in config file.

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
