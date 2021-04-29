#! /usr/bin/env bash

#
# .▄▄ · • ▌ ▄ ·.  ▄▄▄· ▄▄·  ▄▄▄· super
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
# PLUGIN
# C : 2021/04/28
# M : 2021/04/28
# D : Plugins management.

# Plugins must be installed in $HOME/.config/smpcp/plugins and
# must be stored in separate directories.
# Name of exposed plugin functions must start with "plug_".
# If a plugin need to receive player events, a function named
# "__plug_plugin_notify" must be created.
 

declare SMPCP_PLUGINS_DIR="$HOME/.config/smpcp/plugins"

declare -A SOURCES

_get_plugin_list() {
  local plugin
  for plugin in "${SMPCP_PLUGINS_DIR}"/*; do
    echo "${plugin##*/}"
  done
}

_get_plugin_function() {
  # get a plugin function and execute it unless -x option is used.
  # -x makes _get_plugin_function exit with status 0 if the function
  # exists, 1 otherwise.
  # -n search for __plug_plugin_notify function and execute it.

  [[ $1 ]] || return 1

  [[ $1 == "-x" ]] && {
    local EXIST=1
    shift
  }

  [[ $1 == "-n" ]] && {
    local NOTIFY=1
    shift
  }

  local plugin
  plugin="$1"; shift

  [[ -a ${SMPCP_PLUGINS_DIR}/${plugin}/${plugin}.sh ]] || {
    __msg E "plugin not found: ${plugin}."
    return 1
  }

  [[ $* ]] || return 1

  [[ $NOTIFY ]] || {
    local func
    func="$1"; shift
  }

  [[ ${SOURCES[$plugin]} ]] || {
    # shellcheck disable=SC1090
    source "${SMPCP_PLUGINS_DIR}/${plugin}/${plugin}.sh"
    SOURCES[$plugin]=1
  }

  [[ $NOTIFY ]] && {
    while read -r; do
      [[ ${REPLY/declare -f} =~ __plug_${plugin}_notify ]] && {
        __plug_"${plugin}"_notify "$@"
        return $?
      }
    done < <(declare -F)
    return 1
  }

  while read -r; do
    [[ ${REPLY/declare -f} =~ plug_${func} ]] && {
      [[ $EXIST ]] || { plug_"${func}" "$@"; return $?; }
      [[ $EXIST ]] && return 0
    }
  done < <(declare -F)
  __msg E "could not find any plugin command: ${func}"
  return 1
}

_do_plugin_exist() {
  # check whether a plugin exists.
  # exit status:
  # 0 true
  # 1 false

  while read -r; do
    _get_plugin_function -x "$REPLY" "$@" && return 0
  done < <(_get_plugin_list)
  return 1
}

exec_plugin() {
  # execute specified plugin function.
  while read -r; do
    _get_plugin_function "$REPLY" "$@" && return 0
  done < <(_get_plugin_list)
  return 1
}

plugin_notify() {
  # notify all plugins on player event.
  # this function is triggered by smpcpd.
  # usage: plugin_notify <event>

  while read -r; do
    _get_plugin_function -n "$REPLY" "$@"
  done < <(_get_plugin_list)
}
