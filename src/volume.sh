# shellcheck shell=bash

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
# VOLUME
# C : 2021/04/10
# M : 2021/04/15
# D : Volume control.

notify_volume() {
  # display volume change notification.
  local vol="$1"

  [[ $vol ]] || return 1
  notify-send -u low -t 1000 "[smpcp]" "volume: ${vol}%"
}

volume() {
  # show or set volume.
  # usage:
  #   volume
  #   volume [-n] [+|-] <value>

  [[ $1 == "-n" ]] && {
    local NOTIFY=1
    shift
  }

  [[ $1 ]] || {
    local vol
    vol="$(read_config volume)"
    [[ $NOTIFY ]] && {
      notify-volume "$vol"
      return 0
    }
    [[ $NOTIFY ]] || { echo "$vol"; return 0; }
    return 1
  }

  # internal use only.
  # if a volume change occured when player was stopped,
  # useful to set correct volume on play.
  [[ $1 == "auto" ]] && {
    local vol cvol
    cvol="$(fcmd status volume)"
    vol="$(read_config volume)"
    dimmed="$(read_config dim)"

    [[ $cvol -ne "$vol" && $dimmed == "off" ]] && 
      state && cmd setvol $((vol))
    return 0
  }

  local val
  val="$1"

  [[ $val =~ ^[+\|-]?[0-9]+$ ]] && {
    local vol
    vol="$(fcmd status volume)"

    if [[ $val =~ ^[+\|-].*$ ]]; then
      ((vol+=val))
    else
      ((vol=val))
    fi

    ((vol > 100 || vol < 0)) && {
      vol="$(fcmd status volume)"
      [[ $NOTIFY ]] && notify_volume "$vol"
      [[ $NOTIFY ]] || __msg M "volume: ${vol}%"
      return 1
    }

    state || {
      # volume will be set on play.
      write_config volume "$vol"
      [[ $NOTIFY ]] && notify_volume "$vol"
      [[ $NOTIFY ]] || __msg M "volume: ${vol}%"
      return 0
    }

    cmd setvol "$vol"
    write_config volume "$(fcmd status volume)" && {
      [[ $NOTIFY ]] && notify_volume "$vol"
      [[ $NOTIFY ]] || __msg M "volume: ${vol}%"
      write_config dim off
      return 0
    }
    return 1
  }
  __msg E "invalid value."
  return 1
}

dim() {
  # toggle -6dB dimmer.
  # usage: dim

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
    __msg M "dim: off."
    return 0
  elif [[ $dimmed == "off" ]]; then
    local cvol
    cvol="$(fcmd status volume)"
    ((cvol > 1)) && {
      cmd setvol $((cvol/2))
      write_config dim on
      __msg M "dim: on."
      return 0
    }
    __msg M "dim: off."
  fi
}
