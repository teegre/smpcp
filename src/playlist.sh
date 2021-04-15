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
# PLAYLIST
# C │ 2021/04/03
# M │ 2021/04/12
# D │ Queue management.

list() {
  # (kinda) pretty print queue.

  local pl cpos _cmd _fcmd
  pl="$(mktemp)"
  cpos="$(get_current "%pos%")"

  if [[ $(fcmd status playlistlength) -gt 50 ]]; then
    _cmd="cmd -x playlistinfo"
    _fcmd="fcmd -x playlistinfo duration"
  else
    _cmd="cmd playlistinfo"
    _fcmd="fcmd -x playlistinfo duration"
  fi

  ${_cmd} | __parse_song_info "%artist% →%title% →%album%" \
    | awk '{print NR "→" $0}' \
    | sed "s_^${cpos}→_>>→_"  \
    > "$pl"
  
  [[ ! -s "$pl" ]] && {
    __msg M "queue is empty."
    return
  }

  local duration=0 count=0
  while read -r; do
    ((duration+=${REPLY%%.*}))
    ((count++))
  done < <(${_fcmd})

  shopt -s checkwinsize; (:;:)

  column \
    -d -N "pos,artist,title,album" \
    -T "title,album" \
    -c "$COLUMNS" \
    -t -s "→" \
    -o "│ " "$pl"

  local fmt

  ((duration>=3600)) && fmt="%H:%M:%S" || fmt="%M:%S"
  echo -e "---\n$((count)) item(s) - $(TZ=UTC _date "$fmt" $((duration)))"

  rm "$pl" 2> /dev/null
}

add() {
  # add song(s) to queue.
  # song(s) can also be piped.
  # usage: add <uri>

  if (( $# > 0 )); then
    cmd add "$@"
  else
    while IFS= read -r; do
      cmd add "$REPLY"
    done
  fi
}

delete() {
  # delete song(s) from queue.
  # usage:
  #  delete <pos>
  #  delete <start-end>

  [[ $1 =~ ^([0-9]+)-([0-9]+)$ ]] && {
    local start end
    ((start=BASH_REMATCH[1]))
    ((end=BASH_REMATCH[2]))
    ((start>0)) && ((end>0)) && {
      cmd delete "$((start-1)):$((end))" || return 1
      return 0
    }
    __msg E "bad song index."
  }

  [[ $1 =~ ^[0-9]+$ ]] && {
    local pos="$1"
    ((pos>0)) && {
      cmd delete $((pos-1)) || return 1
      return 0
    }
    __msg E "bad song index."
    return 1
  }

  __msg E "syntax error."
  return 1
}

move() {
  # move song(s) within the queue.
  # usage: move [<from> | <start-end>] <to>

  [[ $1 =~ ^([0-9]+)-([0-9]+)$ ]] && {
    local start end
    ((start=BASH_REMATCH[1]))
    ((end=BASH_REMATCH[2]))

    ((start==0 || end==0)) && {
      __msg E "bad song index."
      return 1
    }

    [[ $2 =~ ^[0-9]+$ ]] && {
      local to="$2"
      ((to>0)) && {
        cmd move "$((start-1)):$((end))" "$((to-1))" || return 1
        return 0
      }
      __msg E "bad song index."
      return 1
    }

    __msg E "syntax error."
    return 1
  }

  [[ $1 =~ ^[0-9]+$ ]] && {
    local pos="$1"
    ((pos==0)) && {
      __msg E "bad song index."
      return 1
    }

    [[ $2 =~ ^[0-9]+$ ]] && {
      local to="$2"
      ((to>0)) && {
        cmd move "$((pos-1))" "$((to-1))" || return 1
        return 0
      }
      __msg E "bad song index."
      return 1
    }

    __msg E "syntax error."
    return 1
  }

  __msg E "syntax error."
  return 1
}

crop() {
  # delete all songs from the queue
  # except for the currently playing song.

  local cur_id
  cur_id="$(get_current "%id%")"

  while read -r id; do
    [[ $id != "$cur_id" ]] &&
      cmd deleteid "$id"
  done < <(fcmd playlistinfo "Id")
}

__album_mode() {
  cmd consume 1
  cmd random 0
  cmd single 0
  cmd crossfade 0
  cmd replay_gain_mode album
}

__song_mode() {
  cmd consume 1
  cmd random 1
  cmd single 0
  cmd crossfade 10
  cmd replay_gain_mode track
}

__album_uri() {
  local album_uri
  album_uri="$(get_current)"
  album_uri="${album_uri%/*}"
  echo "$album_uri"
  [[ $album_uri ]] && return 0 || return 1
}

add_album() {
  # add album for current song,
  # or add given album.
  # usage: add_album [-i|-p] [ <artist> <album> ]
  # -i add album after current song.
  # -p starts album playback.
  
  for opt in "$@"; do
    case $opt in
      -i) local INSERT=1; unset PLAY; shift ;;
      -p) local PLAY=1; unset INSERT; shift
    esac
  done

  [[ $1 && $2 ]] && {

    if search albumartist "$1" album "$2" &> /dev/null; then
      [[ $PLAY ]] && cmd clear
      [[ $INSERT ]] && crop
      searchadd albumartist "$1" album "$2"
    else
      __msg E "nothing found."
      return 1
    fi

    __album_mode

    [[ $PLAY ]] && { 
      play 1 || return 1
      __msg M "$(get_current "now playing: %album%")"
    }
    return 0
  }

  [[ $1 || $2 ]] && {
    __msg E "missing option."
    return 1
  }

  local album_uri
  album_uri="$(__album_uri)" || {
    __msg E "no current song."
    return 1
  }

  # does album contains other tracks?
  [[ $(fcmd -c lsinfo "$album_uri" file) -eq 1 ]] && {
    __msg E "'$(get_current "%album%")' no more songs."
    return 1
  }

  if [[ $(get_current "%track%") =~ ^0*1$ ]]; then
    crop
    add "$album_uri"
    delete 2
  else
    state && PLAY=1
    cmd clear
    add "$album_uri"
  fi
  
  __album_mode

  [[ $PLAY ]] && {
    state || play 1
    __msg M "$(get_current "now playing: %album%")"
  }

  return 0
}
