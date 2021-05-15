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
# M : 2021/05/15
# D : Statistics management.

get_sticker() {
  local uri name value
  uri="$1"

  [[ $uri =~ ^https?: ]] && return 1

  name="$2"
  [[ $uri && $name ]] && {
    value="$(cmd sticker get song "$uri" "$name")" || return 1
    [[ $value =~ ^sticker:[[:space:]]${name}=(.+)$ ]] && {
      echo "${BASH_REMATCH[1]}"
      return 0
    }
  }
  return 1
}

set_sticker() {
  local uri name value
  uri="$1"

  [[ $uri =~ ^https?: ]] && return 1

  name="$2"
  value="$3"
  [[ $uri && $name && $value ]] && {
    cmd sticker set song "$uri" "$name" "$value" || return 1
    return 0
  }
  return 1
}

find_sticker() {
  local uri name
  uri="$1"

  [[ $uri =~ ^https?: ]] && return 1

  name="$2"
  while read -r; do
    [[ $REPLY =~ ^sticker:[[:space:]]${name}=(.+)$ ]] &&
      echo "${BASH_REMATCH[1]}"
      local OK=1
  done < <(cmd sticker find song "$uri" "$name")
  [[ $OK ]] && return 0 || return 1
}

delete_sticker() {
  local uri name
  uri="$1"

  [[ $uri =~ ^https?: ]] && return 1

  name="$2"
  [[ $uri && $name ]] && {
    cmd sticker delete song "$uri" "$name" || return 1
    return 0
  }
  return 1
}

update_history_index() {
  local index
  index="$(read_config history_index)" || index=0

  write_config history_index \
    $((index>0?index-1:0))
}

media_update() {
  __is_mpd_running || {
    :> "/tmp/.currentmedia"
    return
  }

  local fmt
  fmt="$(state -p);[[%name% | ]][[%artist%: ]]%title%"

  {
    get_current "$fmt"
  } > "/tmp/.currentmedia"
}

clear_media() { :> "/tmp/.currentmedia"; }

update_stats() {
  
  __is_mpd_running || return 1

  [[ $1 == "--no-playcount" ]] && {
    local NO_PLAYCOUNT=1
    shift
  }

  local uri
  uri="$1"

  [[ $uri ]] || return 1

  [[ $uri =~ ^https?: ]] && return 0

  update_history_index

  set_sticker "$uri" lastplayed "$(now)" || return 1
  
  [[ $NO_PLAYCOUNT ]] || {
    local playcount
    playcount="$(get_sticker "$uri" playcount 2> /dev/null)" || playcount=0

    ((playcount++))
    set_sticker "$uri" playcount "$playcount" ||
      return 1
  }

  get_sticker "$uri" rating &> /dev/null ||
    rating 0 &> /dev/null
  get_sticker "$uri" skipcount &> /dev/null ||
    set_sticker "$uri" skipcount 0

  return 0
}

reset_stats() {

  local uri
  uri=$1

  [[ $uri ]] || return 1

  set_sticker "$uri" lastplayed "-" &&
    set_sticker "$uri" playcount 0 &&
      set_sticker "$uri" skipcount 0 &&
        return 0

  return 1
}

rating() {
  # set current song rating.
  # usage: rating [value]
  # value must be an integer between 0 (unset) and 5.
  # if no given value, print actual rating.

  local cr uri
  uri="$(get_current)"
  cr="$(get_sticker "$uri" rating 2> /dev/null)" || cr=0
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

  [[ $1 =~ ^[0-9]+$ ]] && {
    local r="$1"
    ((r<0 || r>5)) && {
      message E "invalid value."
      return 1
    }
    set_sticker "$uri" rating $((r*2)) || return 1
    message M "$(get_current "%artist%: %title%") [$cr → $r]"
    return 0
  }
  message E "invalid value."
  return 1
}

lastplayed() {
  # print when current song was last played.

  local lsp
  lsp="$(get_sticker "$(get_current)" lastplayed)" || lsp="-"

  echo "$lsp"
}

playcount() {
  # print current song playcount.

  local plc
  plc="$(get_sticker "$(get_current)" playcount 2> /dev/null)" || plc=0

  echo "$plc"
}

skipcount() {
  # print current song skipcount.

  local skc
  skc="$(get_sticker "$(get_current)" skipcount 2> /dev/null)" || {
    echo 0
    return 1
  }

  echo $((skc))
  return 0
}

song_stats() {
  # print current song statistics.

  get_current "%artist%: %title%\n%album% (%date%)"
  echo "===="
  echo "rating:      $(rating)"
  echo "last played: $(lastplayed)"
  echo "play count:  $(playcount)"
  echo "skip count:  $(skipcount)"
}

db_playtime() {
  # print db total playtime
  
  local t
  t="$(fcmd stats db_playtime)"

  secs_to_hms $((t))
  echo
}
