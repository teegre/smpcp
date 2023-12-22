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
# M │ 2023/12/20
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

    ${_cmd} | parse_song_info "$fmt"
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
  done < <(${_cmd} | parse_song_info "%file%→[[%artist%: ]]%title%[[ (%name%)]]→%time%")

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
    [[ $uri =~ ^cdda: ]] && {
      message E "use cdadd command"
    }
    uri="${uri%*/}"
    cmd add "$uri"
  else
    while IFS= read -r; do
      cmd add "$REPLY"
    done
  fi
}

cdadd() {
  # add audio cd track(s) to queue.
  # usage: cdadd [track | start-end | track1 ... trackN]
  # without parameter, cdadd adds
  # all tracks to the queue.

  # check if there's an audio cd in the drive
  # and get track count.

  which cdparanoia &> /dev/null || {
    message E "missing 'cdparanoia' dependency."
    return 1
  }

  local tracks=0
  tracks="$(cdparanoia -Qs |& grep -P '^\s+\d+\.' | wc -l)"

  ((tracks==0)) && {
    message E "no disc."
    return 1
  }

  [[ $1 == "-p" ]] && {
    state && {
      local ext
      ext="$(get_current "%ext%")"
      [[ $ext == "cdda" ]] && {
        message W "already playing."
        return 1
      }
    }
    local PLAY=1
    shift
    cmd clear
    __album_mode
  }

  (( $#>1 )) && {
    for track in "$@"; do
      if ((track>0)) && ((track<=tracks)); then
        cmd add "cdda:///${track}" || return 1
      else
        message E "${track}: bad track index [skipped]."
        continue
      fi
    done
    [[ $PLAY ]] && cmd play
    return 0
  }

  [[ $1 =~ ^([0-9]+)-([0-9]+)$ ]] && {
    local start end track
    ((start=BASH_REMATCH[1]))
    ((end=BASH_REMATCH[2]))
    ((start<tracks)) && ((end<=tracks)) && ((start>0)) && ((end>0)) && {
      for (( track=start; track<=end; track++ )); do
        cmd add "cdda:///${track}" || return 1
      done
      [[ $PLAY ]] && cmd play
      return 0
    }
    message E "bad track index."
    return 1
  }

  [[ $1 =~ ^[0-9]+$ ]] && {
    local track="$1"
    ((track>0)) && ((track<=tracks)) && {
      cmd add "cdda:///${1}" || return 1
      [[ $PLAY ]] && cmd play
      return 0
    }
    message E "bad track index."
    return 1
  }

  for (( track=1; track<=tracks; track++ )); do
    cmd add "cdda:///${track}" || return 1
  done
  [[ $PLAY ]] && cmd play
  return 0
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
  is_daemon && get_mode &> /dev/null && state && {
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

  is_daemon && get_mode &> /dev/null && state
    update_daemon
}

__album_mode() {
  cmd consume 1
  cmd random 0
  cmd single 0
  cmd crossfade 0
  cmd repeat 0
  if [[ $(read_config "album_mode_replaygain") == "on" ]]; then
    cmd replay_gain_mode album
  else
    cmd replay_gain_mode off
  fi
}

__song_mode() {
  cmd consume 1
  cmd random 1
  cmd single 0

  local xf
  xf="$(read_config song_mode_xfade_duration)" || xf=10
  cmd crossfade $((xf))

  cmd repeat 0
  cmd replay_gain_mode track
}

__normal_mode() {
  cmd consume 0
  cmd random 0
  cmd single 0
  cmd crossfade 0
  cmd repeat 0
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
  uri="$(album_uri)" || {
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

add_song() {
  # add the given song and play it right after the current one.
  # usage: add_song artist title

  local -a uri # in case of multiple results.
  local idx=0

  while read -r; do
    uri+=("$REPLY")
  done <<< $(search artist "$1" title "$2")

  local len="${#uri[@]}"

  (( len > 1 )) && {
    # multiple results found, show them...
    local i r
    for (( i = 0; i < $len; i++ )); do
      printf "%0${#len}d. │ %s\n" $((i+1)) "$(get_info "${uri[$i]}" "%artist%: %title% (%album%)")"
    done
    read -p "1-${len}? " -r r
    [[ $r =~ [0-9]+ ]] || { message E "nothing added."; return 1; }
    ((r < 1)) || ((r > ${len})) && { message E "bad index."; return 1; }
    idx="$((r-1))"
  }

  [[ $uri ]] && {
    add "${uri[$idx]}"
    local pos
    ((pos=$(queue_length)-1))
    cmd prio 1 $((pos))
    return 0
  }
  message E "nothing found."
  return 1
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
  # usage: list_playlist [name [index]]

  local name index
  name="$1"; shift
  index="$1"; shift

  [[ $index ]] && {
    [[ $index =~ [0-9]+ ]] || {
      message E "invalid index."
      return 1
    }
  }

  [[ $name ]] || { fcmd listplaylists playlist; return; }

  [[ $name ]] && {
    [[ $index ]] && {
      local count=0
      while read -r; do
        ((++count))
        (( count == index )) && {
          echo "$REPLY"
          return 0
        }
      done < <(fcmd listplaylist "$name" file)
      return 1
    }

    fcmd listplaylist "$name" file
  }
}

load() {
  # load playlist into the queue.
  # usage: load <name> [[pos]|[start-end]...]

  local name
  name="$1"
  shift

  [[ $1 ]] || {
    cmd load "$name" || return 1
    return 0
  }

  local pos

  for pos in "$@"; do
    [[ $pos =~ ^([0-9]+)-([0-9]+)$ ]] && {
      local start end
      ((start=BASH_REMATCH[1]))
      ((end=BASH_REMATCH[2]))
      ((start>0)) && ((end>0)) && {
        cmd load "$name" "$((start-1)):$((end))" || return 1
        continue
      }
      message E "bad song index."
      return 1
    }

    [[ $pos =~ ^[0-9]+$ ]] && {
      ((pos>0)) && {
        cmd load "$name" $((pos-1)) || return 1
        continue
      }
      message E "bad song index."
      return 1
    }
  done
}

cload() {
  # clear the current queue and load a playlist.

  local pl="$1"

  [[ $pl ]] || return 1
  
  list_playlist "$pl" > /dev/null || return 1

  local pos="$2"

  _mode off
  
  state && local PLAY=1

  cmd clear

  load "$pl" "$pos"

  [[ $PLAY ]] && play 1
}

save() {
  # save the current queue as a playlist.
  # usage: save <name>

  list_playlist "$1" &> /dev/null &&
    remove "$1"

  cmd save "$1"
}

remove() {
  # remove a stored playlist
  # usage: remove <name>

  cmd rm "$1"
}
