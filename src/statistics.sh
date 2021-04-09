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
# STATISTICS
# C : 2021/04/08
# M : 2021/04/09
# D : Statistics management.

get_sticker() {
  local uri param value
  uri="$1"
  param="$2"
  [[ $uri && $param ]] && {
    value="$(fcmd sticker get song "$uri" "$param" sticker)" || return 1
    [[ $value =~ ^$param=(.+)$ ]] && {
      echo "${BASH_REMATCH[1]}"
      return 0
    }
  }
  return 1
}

set_sticker() {
  local uri param value
  uri="$1"
  param="$2"
  value="$3"
  [[ $uri && $param && $value ]] && {
    cmd sticker set song "$uri" "$param" "$value" || return 1
    return 0
  }
  return 1
}



media_update() {
  __is_mpd_running || {
    echo > "$HOME/.config/currentmedia"
    return
  }

  local fmt='artist %artist%\ntitle %title%\nalbum %album%\ndate %date%'
  {
    state -p
    getcurrent "$fmt"
  } > "$HOME/.config/currentmedia"
}

update_stats() {
  
  __is_mpd_running || return 1

  local uri
  uri="$1"

  [[ $uri ]] || return 1

  set_sticker "$uri" lastplayed "$(now)" || return 1
  
  local playcount
  playcount="$(get_sticker "$uri" playcount)"
  ((playcount++))
  set_sticker "$uri" playcount "$playcount" || return 1

  return 0
}

reset_stats() {

  __is_mpd_running || return 1

  local uri
  uri=$1

  [[ $uri ]] || return 1

  cmd sticker delete song "$uri" lastplayed &&
    cmd sticker delete song "$uri" playcount &&
      cmd sticker delete song "$uri" skipcount &&
        return 0

  return 1
}
