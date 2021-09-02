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
# MUTE
# C : 2021/07/04
# M : 2021/09/02
# D : Simple mute plugin

export PLUG_MUTE_VERSION="0.1"

help_mute() {
  echo "args=[on|off]; desc=(un)mute main output"
}

plug_mute() {
  local outpt st
  outpt="$(read_config mute_output_name)" || return 1
  [[ $1 ]] && {
    case $1 in
      on ) set_output "$outpt" on  &> /dev/null && message M "unmuted." ;;
      off) set_output "$outpt" off &> /dev/null && message M "muted." ;;
      *  ) return 1
    esac
    return 0
  }
  st="$(get_output_state "$outpt")" || return 1
  case $st in
    0 ) set_output "$outpt" on  &> /dev/null && message M "unmuted." ;;
    1 ) set_output "$outpt" off &> /dev/null && message M "muted." ;;
  esac

  return 0
}
