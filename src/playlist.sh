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
# PLAYLIST
# C │ 2021/04/03
# M │ 2021/04/08
# D │ Queue management.

list() {
  # (kinda) pretty print queue.

  __is_mpd_running || return 1
  
  local cols cpos pl

  shopt -s checkwinsize; (:;:)
  ((cols=COLUMNS))
  
  pl="$(mktemp)"

  cpos="$(getcurrent "%pos%")"

  cmd playlistinfo | __parse_song_info "%artist% →%title% →%album%" \
    | awk '{print NR "→" $0}' \
    | sed "s_^${cpos}→_>>→_"  \
    > "$pl"
  
  [[ ! -s "$pl" ]] && {
    __msg M "queue is empty."
    return
  }

  column \
    -d -N "pos,artist,title,album" \
    -T "title,album" \
    -c "$cols" \
    -t -s "→" \
    -o "│ " "$pl" | less -F

  rm "$pl" 2> /dev/null
}

add() {
  # add song(s) to queue.
  # song(s) can also be piped.
  # usage: add <uri>

  __is_mpd_running || return 1

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

  __is_mpd_running || return 1

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

  __is_mpd_running || return 1

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

  __is_mpd_running || return 1

  local cur_id
  cur_id="$(getcurrent "%id%")"

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
  album_uri="$(getcurrent)"
  album_uri="${album_uri%/*}"
  echo "$album_uri"
  [[ $album_uri ]] && return 0 || return 1
}

add_album() {
  # add current song's album
  # or add given album.
  # usage: add_album [-p] [ <artist> <album> ]
  # -p starts playback if needed.
  
  __is_mpd_running || return 1

  [[ $1 == "-p" ]] && {
    local PLAY=1
    shift
  }

  [[ $1 && $2 ]] && {

    cmd clear

    if search artist "$1" album "$2" &> /dev/null; then
      searchadd artist "$1" album "$2"
    elif search albumartist "$1" album "$2" &> /dev/null; then
      searchadd albumartist "$1" album "$2"
    else
      __msg E "nothing found."
      return 1
    fi

    __album_mode

    [[ $PLAY ]] && { 
      play 1 || return 1
      __msg M "$(getcurrent "now playing: %album%")"
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
    __msg W "no more songs."
    return 1
  }

  if [[ $(getcurrent "%track%") =~ ^0*1$ ]]; then
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
    __msg M "$(getcurrent "now playing: %artist% - %album%")"
  }

  return 0
}