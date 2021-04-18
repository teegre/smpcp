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
# M │ 2021/04/18
# D │ Queue management.

list_queue() {
  # print queue.
  # usage: list_queue [-f [format]]

  local len
  len="$(fcmd status playlistlength)"

  ((len == 0)) && {
    __msg M "queue is empty."
    return
  }

  local _cmd

  if ((len > 50)); then
    _cmd="cmd -x playlistinfo"
  else
    _cmd="cmd playlistinfo"
  fi

  [[ $1 == "-f" ]] && {
    local fmt
    fmt="${2:-"%file%"}"

    ${_cmd} | _parse_song_info "$fmt"
    return
  }

  local cpos
  cpos="$(get_current "%pos%")"
  
  local pos=0 maxwidth entry title dur=0

  shopt -s checkwinsize; (:;:)

  ((maxwidth=COLUMNS-${#len}-9))

  while read -r; do
    ((++pos))

    IFS=$'\n' read -d "" -ra entry <<< "${REPLY/→/$'\n'}"
    title="${entry[0]}"
    ((dur+=${entry[1]%%.*}))

    ((${#title} > maxwidth)) && title="${title:0:$((maxwidth))}…"
    if ((pos == cpos)); then
      printf "%-${#len}s  │ %s\n" ">" "$title"
    else
      printf "%0${#len}d. │ %s\n" "$pos" "$title"
    fi
  done < <(${_cmd} | _parse_song_info "%artist%: %title%→%duration%")

  local trk
  ((pos>1)) && trk="tracks" || trk="track"
  echo "---"
  echo "$((pos)) $trk - $(secs_to_hms $((dur)))"
}

add() {
  # add song(s) to queue.
  # song(s) can also be piped.
  # usage: add <uri>

  if (( $# > 0 )); then
    local uri
    uri="${*}"
    uri="${uri%*/}"
    cmd add "$uri"
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

clear_queue() {
  _daemon && get_mode &> /dev/null && {
    cmd clear
    update_daemon
    return
  }

  cmd clear
}

crop() {
  # delete all songs from the queue
  # except for the currently playing song.

  local cur_id
  cur_id="$(get_current "%id%")" || return 1

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

  local uri
  uri="$(_album_uri)" || {
    __msg E "no current song."
    return 1
  }

  # does album contains other tracks?
  [[ $(fcmd -c lsinfo "$uri" file) -eq 1 ]] && {
    __msg E "'$(get_current "%album%")' no more songs."
    return 1
  }

  [[ $INSERT ]] && crop
  [[ $PLAY ]] && cmd clear

  add "$uri"

  [[ $INSERT ]] &&
    [[ $(get_current "%track%") =~ ^0*1$ ]] &&
      delete 2
  
  __album_mode

  [[ $PLAY ]] && {
    play 1
    __msg M "$(get_current "now playing: %album%")"
  }

  return 0
}

queue_is_empty() {
  # check whether queue is empty.
  local count
  count="$(fcmd status playlistlength)"
  return $((count>0?1:0))
}
