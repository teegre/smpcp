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
# STATISTICS
# C : 2021/04/08
# M : 2021/04/16
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

delete_sticker() {
  local uri param
  uri="$1"
  param="$2"
  [[ $uri && $param ]] && {
    cmd sticker delete song "$uri" "$param" || return 1
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
    echo "status $(state -p)"
    get_current "$fmt"
  } > "$HOME/.config/currentmedia"
}

clear_media() { :> "$HOME/.config/currentmedia"; }

update_stats() {
  
  __is_mpd_running || return 1

  local uri
  uri="$1"

  [[ $uri ]] || return 1

  set_sticker "$uri" lastplayed "$(now)" || return 1
  
  local playcount
  playcount="$(get_sticker "$uri" playcount 2> /dev/null)" || playcount=0
  ((playcount++))
  set_sticker "$uri" playcount "$playcount" || return 1

  return 0
}

reset_stats() {

  local uri
  uri=$1

  [[ $uri ]] || return 1

  cmd sticker delete song "$uri" lastplayed &&
    cmd sticker delete song "$uri" playcount &&
      cmd sticker delete song "$uri" skipcount &&
        return 0

  return 1
}

rating() {
  # set current song rating.
  # usage: rating [value]
  # value must be an integer between 0 (unset) and 5.
  # if no given value, print actual rating.

  local cr uri
  cr="$(get_sticker "$(get_current)" rating 2> /dev/null)" || cr=0
  ((cr/=2))

  [[ $1 ]] || {
    case $cr in
      0) echo "-----" ;;
      1) echo "*----" ;;
      2) echo "**---" ;;
      3) echo "***--" ;;
      4) echo "****-" ;;
      5) echo "*****"
    esac
    return 0
  }

  uri="$(get_current)"

  [[ $1 =~ ^[0-9]+$ ]] && {
    local r="$1"
    ((r<0 || r>5)) && {
      __msg E "invalid value."
      return 1
    }
    if [[ $r -eq 0 ]]; then
      delete_sticker "$uri" rating || return 1
      return 0
    else
      set_sticker "$uri" rating $((r*2)) || return 1
      __msg M "$(get_current "%artist%: %title%") $cr → $r"
      return 0
    fi
  }
  __msg E "invalid value."
  return 1
}

playcount() {
  # print current song playcount.

  local plc
  plc="$(get_sticker "$(get_current)" playcount 2> /dev/null)" || plc=0
  echo "$plc"
}
