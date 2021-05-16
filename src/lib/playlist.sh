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
# M │ 2021/05/16
# D │ Queue/playlist management.

list_queue() {
  # print queue.
  # usage: list_queue [-f [format]]

  queue_is_empty && {
    >&2 message M "queue is empty."
    return 1
  }

  local len _cmd

  len="$(fcmd status playlistlength)"

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

    IFS=$'\n' read -d "" -ra entry <<< "${REPLY//→/$'\n'}"

    title="${entry[1]}"

    # no title?
    [[ $title ]] || title="${entry[0]}"

    [[ ${entry[2]} =~ [0-9]+ ]] &&
      ((dur+=entry[2]))

    ((${#title} > maxwidth)) && title="${title:0:$((maxwidth))}…"
    if ((pos == cpos)); then
      printf "%-${#len}s  │ %s\n" ">" "$title"
    else
      printf "%0${#len}d. │ %s\n" "$pos" "$title"
    fi
  done < <(${_cmd} | _parse_song_info "%file%→[[%artist%: ]]%title%[[ (%name%)]]→%time%")

  local trk
  ((pos>1)) && trk="tracks" || trk="track"
  echo "---"
  echo "$((pos)) $trk - $(secs_to_hms $((dur)))"
}

is_in_queue() {
  # check whether a URI is in the queue
  # usage: is_in_queue <uri>

  local uri
  uri="$1"

  while read -r; do
    [[ $REPLY == "$uri" ]] && return 0
  done < <(list_queue -f)

  return 1
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
    message E "bad song index."
    return 1
  }

  [[ $1 =~ ^[0-9]+$ ]] && {
    local pos="$1"
    ((pos>0)) && {
      cmd delete $((pos-1)) || return 1
      return 0
    }
    message E "bad song index."
    return 1
  }

  message E "syntax error."
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
      message E "bad song index."
      return 1
    }

    [[ $2 =~ ^[0-9]+$ ]] && {
      local to="$2"
      ((to>0)) && {
        cmd move "$((start-1)):$((end))" "$((to-1))" || return 1
        return 0
      }
      message E "bad song index."
      return 1
    }

    message E "syntax error."
    return 1
  }

  [[ $1 =~ ^[0-9]+$ ]] && {
    local pos="$1"
    ((pos==0)) && {
      message E "bad song index."
      return 1
    }

    [[ $2 =~ ^[0-9]+$ ]] && {
      local to="$2"
      ((to>0)) && {
        cmd move "$((pos-1))" "$((to-1))" || return 1
        return 0
      }
      message E "bad song index."
      return 1
    }

    message E "syntax error."
    return 1
  }

  message E "syntax error."
  return 1
}

clear_queue() {
  _daemon && get_mode &> /dev/null && state && {
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

  local id

  while read -r id; do
    [[ $id != "$cur_id" ]] &&
      cmd deleteid "$id"
  done < <(fcmd playlistinfo "Id")

  _daemon && get_mode &> /dev/null && state
    update_daemon
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

__normal_mode() {
  cmd consume 0
  cmd random 0
  cmd single 0
  cmd crossfade 0
  cmd replay_gain_mode auto
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
      message E "nothing found."
      return 1
    fi

    __album_mode

    [[ $PLAY ]] && { 
      play 1 || return 1
      message M "$(get_current "now playing: %album%")"
    }
    return 0
  }

  [[ $1 || $2 ]] && {
    message E "missing option."
    return 1
  }

  local uri
  uri="$(_album_uri)" || {
    message E "no current song."
    return 1
  }

  # does album contains other tracks?
  [[ $(fcmd -c lsinfo "$uri" file) -eq 1 ]] && {
    message E "'$(get_current "%album%")' no more songs."
    return 1
  }

  [[ $INSERT ]] && crop
  [[ $PLAY ]] && {
    if [[ $(get_current "%track%") =~ ^0*1$ ]]; then
      crop
      INSERT=1
      unset PLAY
    else
     cmd clear
    fi
  }

  add "$uri"

  [[ $INSERT ]] &&
    [[ $(get_current "%track%") =~ ^0*1$ ]] &&
      delete 2
  
  __album_mode

  [[ $PLAY ]] && {
    play 1
    message M "$(get_current "now playing: %album%")"
  }

  return 0
}

queue_length() {
  fcmd status playlistlength
}

queue_is_empty() {
  # check whether queue is empty.
  local count
  count="$(fcmd status playlistlength)"
  return $((count>0?1:0))
}

list_playlist() {
  # list stored playlists or list songs in a given stored playlist.
  # usage: list_playlist [name]

  [[ $1 ]] && fcmd listplaylist "$1" file
  [[ $1 ]] || fcmd listplaylists playlist
}

load() {
  # load playlist into the queue.
  # usage: load <name> [start-end]

  local name
  name="$1"
  shift

  [[ $1 =~ ^([0-9]+)-([0-9]+)$ ]] && {
    local start end
    ((start=BASH_REMATCH[1]))
    ((end=BASH_REMATCH[2]))
    ((start>0)) && ((end>0)) && {
      cmd load "$name" "$((start-1)):$((end))" || return 1
      return 0
    }
    message E "bad song index."
    return 1
  }

  [[ $1 = ^[0-9]+$ ]] && {
    local pos="$1"
    ((pos>0)) && {
      cmd load "$name" $((pos)) || return 1
      return 0
    }
    message E "bad song index."
    return 1
  }

  cmd load "$name"
}
