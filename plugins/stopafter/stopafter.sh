# shellcheck shell=bash

#
# .▄▄ · • ▌ ▄ ·.  ▄▄▄· ▄▄·  ▄▄▄· super
# ▐█ ▀. ·██ ▐███▪▐█ ▄█▐█ ▌▪▐█ ▄█ music
# ▄▀▀▀█▄▐█ ▌▐▌▐█· ██▀·██ ▄▄ ██▀· player
# ▐█▄▪▐███ ██▌▐█▌▐█▪·•▐███▌▐█▪·• client
#  ▀▀▀▀ ▀▀  █▪▀▀▀.▀   ·▀▀▀ .▀    plus+
#
# This file is a smpcp plugin.
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
# STOPAFTER
# C : 2021/05/01
# M : 2021/05/30
# D : Stop playback after current song.

# shellcheck source=/usr/lib/smpcp/notify.sh
source "${SMPCP_LIB}/notify.sh"

export PLUG_STOPAFTER_VERSION="0.1"

help_stopafter() {
  echo "args=[-n] [on|off]; desc=stop playback after current song."
}

__plug_stopafter_notify() {
  local s
  s="$(read_config stopafter)" || return
  [[ $s == "off" ]] && return

  if [[ $1 == "pause" || $1 == "stop" || $1 == "change" || $1 == "quit" ]]; then
    plug_stopafter off &> /dev/null
  elif [[ $1 == "end" ]]; then
    pause
    plug_stopafter off &> /dev/null
  fi
}

plug_stopafter() {

  state || {
    message E "not playing."
    return 1
  }

  is_daemon || {
    message E "stopafter: daemon is not running."
    return 1
  }

  [[ $1 == "-n" ]] && { 
    local NOTIFY=1
    shift
  }

  [[ $1 ]] && {
    if [[ $1 == "on" ]]; then
      write_config stopafter on || return 1

      local xf
      xf="$(xfade | cut -d' ' -f 2)"
      [[ $xf != "off" ]] && {
        write_config stopafter_xfade $((xf))
        cmd crossfade 0
      }

      [[ $NOTIFY ]] && stopafter_notify "on"
      [[ $NOTIFY ]] || message M "stop after current: on."
      return 0

    elif [[ $1 == "off" ]]; then

      local xf
      xf="$(read_config stopafter_xfade)" && {
        cmd crossfade $((xf))
        remove_config stopafter_xfade
      }

      write_config stopafter off || return 1

      [[ $NOTIFY ]] && stopafter_notify "off"
      [[ $NOTIFY ]] || message M "stop after current: off."
      return 0
    fi
  }

  [[ $(read_config stopafter) == "on" ]] && {
    local xf
    xf="$(read_config stopafter_xfade)" && {
      cmd crossfade $((xf))
      remove_config stopafter_xfade
    }

    write_config stopafter off || return 1

    [[ $NOTIFY ]] && stopafter_notify "off"
    [[ $NOTIFY ]] || message M "stop after current: off."
    return 0
  }

  write_config stopafter on || return 1

  local xf
  xf="$(xfade | cut -d' ' -f 2)"
  [[ $xf != "off" ]] && {
    write_config stopafter_xfade $((xf))
    cmd crossfade 0
  }

  [[ $NOTIFY ]] && stopafter_notify "on"
  [[ $NOTIFY ]] || message M "stop after current: on."
}

stopafter_notify() {
  notify_player "stopafter: ${1}."
}
