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
# M : 2021/05/05
# D : Stop playback after current song.

export PLUG_STOPAFTER_VERSION="0.1"

help_stopafter() {
  echo "args=[-n] [on|off]; desc=stop playback after current song."
}

__plug_stopafter_notify() {
  local s
  s="$(read_config stopafter)" || s="off"

  if [[ $1 == "pause" || $1 == "stop" ]]; then
    [[ $s == "on" ]] && {
      plug_stopafter off &> /dev/null || return 1
      return 0
    }
  fi
}

plug_stopafter() {
  state || {
    message E "not playing."
    return 1
  }

  [[ $1 == "-n" ]] && { 
    local NOTIFY=1
    shift
  }

  [[ $1 ]] && {
    if [[ $1 == "on" ]]; then
      single 1 &> /dev/null || return 1
      write_config stopafter on || return 1
      [[ $NOTIFY ]] && stopafter_notify "on"
      [[ $NOTIFY ]] || message M "stop after current: on."
      return 0
    elif [[ $1 == "off" ]]; then
      single 0 &> /dev/null || return 1
      write_config stopafter off || return 1
      [[ $NOTIFY ]] && stopafter_notify "off"
      [[ $NOTIFY ]] || message M "stop after current: off."
      return 0
    fi
  }

  [[ $(read_config stopafter) == "on" ]] && {
    single 0 &> /dev/null || return 1
    write_config stopafter off || return 1
    [[ $NOTIFY ]] && stopafter_notify "off"
    [[ $NOTIFY ]] || message M "stop after current: off."
    return 0
  }

  single 1 &> /dev/null || return 1
  write_config stopafter on || return 1
  [[ $NOTIFY ]] && stopafter_notify "on"
  [[ $NOTIFY ]] || message M "stop after current: on."
}

stopafter_notify() {
  notify-send -i "$SMPCP_ICON" -t 1500 "stopafter: ${1}."
}
