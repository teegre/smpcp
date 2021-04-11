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
# VOLUME
# C : 2021/04/10
# M : 2021/04/11
# D : Volume control.

volume() {
  # show or set volume.
  # usage:
  #   volume
  #   volume [+ | -] <value>

  [[ $1 ]] || {
    read_config volume && return 0
    return 1
  }

  local val
  val="$1"

  [[ $val =~ ^[\+\|\-]?[0-9]+$ ]] && {
    local vol
    vol="$(fcmd status volume)"

    if [[ $val =~ ^[\+|\-].*$ ]]; then
      ((vol+=val))
    else
      ((vol=val))
    fi
    cmd setvol "$vol" || return 1
    write_config volume "$(fcmd status volume)" && {
      __msg M "volume: ${vol}%"
      return 0
    }
    return 1
  }
  __msg E "invalid value."
  return 1
}

dim() {
  # -6dB dimmer.

  local s
  s="$(state -p)"

  [[ $s == "stop" || $s == "pause" ]] &&
    return 1

  local dimmed
  dimmed="$(read_config dim)"

  if [[ $dimmed == "on" ]]; then
    local svol
    svol="$(read_config volume)"
    cmd setvol $((svol))
    write_config dim off
    __msg M "dim off."
  elif [[ $dimmed == "off" ]]; then
    local cvol
    cvol="$(fcmd status volume)"
    cmd setvol $((cvol/2))
    write_config dim on
    __msg M "dim on."
  fi
}
