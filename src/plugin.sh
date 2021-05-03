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
# M : 2021/05/03
# D : Plugins management.

# Plugins must be installed in $HOME/.config/smpcp/plugins and
# must be stored in separate directories.
# Name of exposed plugin functions must start with "plug_".
# If a plugin need to receive player events, a function named
# "__plug_plugin-name_notify" must be created.
 
declare SMPCP_PLUGINS_DIR="$HOME/.config/smpcp/plugins"

# declare -A SOURCES

get_plugin_list() {
  local plugin
  for plugin in "${SMPCP_PLUGINS_DIR}"/*; do
    echo "${plugin##*/}"
  done
}

get_all_plugin_functions() {
  # print all functions for given plugin.
  # usage: get_all_plugin_functions <plugin-name>
  local plugin pathname func
  plugin="$1"
  pathname="${SMPCP_PLUGINS_DIR}/${plugin}/${plugin}.sh"
  # shellcheck disable=SC1090
  source "$pathname"

  while read -r func; do
    [[ ${func/declare -f } =~ ^plug_.*|^help_.* ]] &&
      echo "${func/declare -f }"
  done < <(declare -F)
}

get_plugin_function() {
  # get a plugin function and execute it unless -x option is used.
  # usage: get_plugin_function [-x | -n | -h] <plugin> <function>
  # (function name without the "plug_" prefix)
  # -x makes get_plugin_function exit with status 0 if the function
  # exists, 1 otherwise.
  # -n search for __plug_plugin-name_notify function and execute it.
  # -h search for help_ function.

  [[ $1 ]] || return 1

  [[ $1 == "-x" ]] && {
    local EXIST=1
    shift
  }

  [[ $1 == "-n" ]] && {
    local NOTIFY=1
    shift
  }

  [[ $1 == "-h" ]] && {
    local HELP=1
    shift
  }

  local plugin
  plugin="$1"; shift

  [[ -a ${SMPCP_PLUGINS_DIR}/${plugin}/${plugin}.sh ]] ||
    return 1

  # [[ $* ]] || return 1

  [[ $NOTIFY ]] || {
    local func
    func="$1"; shift
  }

  # [[ ${SOURCES[$plugin]} ]] || {
  # shellcheck disable=SC1090
  source "${SMPCP_PLUGINS_DIR}/${plugin}/${plugin}.sh"
  # SOURCES[$plugin]=1
  # }

  [[ $NOTIFY ]] && {
    unset NOTIFY
    while read -r; do
      [[ ${REPLY/declare -f } =~ __plug_${plugin}_notify ]] && {
        __plug_"${plugin}"_notify "$@"
        return $?
      }
    done < <(declare -F)
    return 1
  }

  local prefix
  [[ $HELP ]] && prefix="help" || prefix="plug"
  while read -r; do
    [[ ${REPLY/declare -f } =~ ^${prefix}_${func} ]] && {
      [[ $EXIST ]] || { "${prefix}_${func}" "$@"; return $?; }
      [[ $EXIST ]] && return 0
    }
  done < <(declare -F)
  # message E "could not find any plugin command: ${func}"
  return 1
}

plugin_exists() {
  # check whether a plugin exists.
  # exit status:
  # 0 true
  # 1 false

  while read -r; do
    get_plugin_function -x "$REPLY" "$@" && return 0
  done < <(get_plugin_list)
  return 1
}

exec_plugin() {
  # execute specified plugin function.
  while read -r; do
    get_plugin_function "$REPLY" "$@" && return $?
  done < <(get_plugin_list)
  return 1
}

plugin_notify() {
  # notify all plugins on player event.
  # this function is triggered by smpcpd.
  # usage: plugin_notify <event>

  while read -r; do
    get_plugin_function -n "$REPLY" "$@"
  done < <(get_plugin_list)
}

plugin_help() {
  # print help text for the given function.

  local func sp helpstr args desc
  sp="[[:space:]]"

  while read -r plugin; do
    while read -r func; do
      helpstr="$(get_plugin_function -h "$plugin" "${func/help_}")"
      [[ $helpstr ]] || continue
      [[ $helpstr =~ ^args${sp}*=${sp}*(.*)${sp}*\;${sp}*desc${sp}*=${sp}*(.*)$ ]] && {
        args="${BASH_REMATCH[1]}"
        desc="${BASH_REMATCH[2]}"
        echo -e "smpcp ${func/help_} $args $desc"
      }
    done < <(get_all_plugin_functions "$plugin")
  done < <(get_plugin_list)
}
