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
# CLIENT
# C │ 2021/04/02
# M │ 2021/04/08
# D │ Basic MPD client.

__is_mpd_running() {
  # check whether mpd is running or not.

  local pidfile="$HOME/.config/mpd/pid"
  local pid
  [[ -s $pidfile ]] && {
    pid="$(<"$pidfile")"
    kill -0 "$pid" &> /dev/null && return 0
  }
  return 1
}

__cmd() {
# send a command to music player daemon.
# usage: __cmd [-x] <command> [options]
# -x sets the buffering output delay time (source: netcat manpage) to 1 second.
# it prevents netcat from prematurely returning when an expensive task is running
# (i.e listall).

__is_mpd_running || return 1

local host port nccmd
host="${MPD_HOST:-localhost}"
port="${MPD_PORT:-6600}"

if [[ $1 == "-x" ]]; then
  nccmd="netcat -i 1 $host $port"
  shift
else
  nccmd="netcat $host $port"
fi

if [[ $1 =~ ^idle.*$ ]]; then
  case $1 in
    idle    ) shift; ./idlecmd "$@" ;;
    idleloop) shift; ./idlecmd loop "$@" ;;
    *       ) echo "ACK [] {} invalid command."; return
  esac
  return $?
fi

# preserve quoted arguments.
local arg arglist
for arg in "${@}"; do
  if [[ $arg =~ ^.*[[:space:]]+.* ]]; then
    arglist+=("\"$arg\"")
  else
    arglist+=("$arg")
  fi
done

${nccmd} << CMD
${arglist[@]:-}
close
CMD

}

cmd() {
  # like __cmd + filter errors.
  __is_mpd_running || return 1

  while read -r; do
    [[ $REPLY =~ ^OK.+$ ]] && continue
    [[ $REPLY == "OK" ]] && return 0
    [[ $REPLY =~ ^ACK[[:space:]]\[.*\][[:space:]]\{.*\}[[:space:]](.+)$ ]] && {
      __msg E "${BASH_REMATCH[1],,}"
      return 1
    }
    [[ $REPLY ]] && echo "$REPLY"
  done < <(__cmd "$@")
}

fcmd() {
  # filter command output by printing value for a given key.
  # usage: fcmd [-c] [-x] <command> [options] <key>
  # options:
  # -c print line count only (must be 1st argument).
  # -x see "__cmd".

  __is_mpd_running || return 1

  [[ $1 == "-c" ]] && {
    local COUNT=1
    shift
  }

  # key is the last option.
  local key="${!#}"

  # rebuild argument list.
  local i arg arglist
  for ((i=1;i<$#;i++)); do
    arglist+=("${!i}")
  done
  
  local count=0

  while read -r; do
    [[ $REPLY =~ ^$key:[[:space:]](.+)$ ]] && {
      ((count++))
      if [[ $COUNT ]]; then
        continue
      else
        echo "${BASH_REMATCH[1]}"
      fi
    }
  done < <(cmd "${arglist[@]}")

  [[ $COUNT ]] && echo $((count))
  ((count)) && return 0 || return 1
}

state() {
  # music player playback state.
  # usage: state [-p]
  # return values:
  # 0 ) playing or paused.
  # 1 ) stopped.
  # -p option print actual state (play, pause or stop).

  __is_mpd_running || return 1

  local state
  state="$(fcmd status state)"

  [[ $1 == "-p" ]] && echo "$state"

  if [[ $state == "play" || $state == "pause" ]]; then
    return 0
  else
    return 1
  fi
}

__parse_song_info() {
  # parse song information in the given format.
  #
  # available tags:
  #
  # %file% %last-modified% %format%
  # %artist% %title% %album% %albumartist% %genre% %date%
  # %time% %duration%
  # %pos% %id%

  [[ $1 == "-s" ]] && {
    local search=1
    shift
  }

  local fmt
  fmt="${1:-%artist% - %title%}"

  local count=0

  while IFS= read -r; do

    [[ $REPLY =~ ^file:[[:space:]](.+)$ ]] && {
      fmt="${fmt//"%file%"/${BASH_REMATCH[1]}}"
      continue
    }
    [[ $REPLY =~ ^Last-Modified:[[:space:]](.+)$ ]] && {
      fmt="${fmt//"%last-modified%"/${BASH_REMATCH[1]}}"
      continue
    }
    [[ $REPLY =~ ^Format:[[:space:]](.+)$ ]] && {
      fmt="${fmt//"%format%"/${BASH_REMATCH[1]}}"
      continue
    }
    [[ $REPLY =~ ^Artist:[[:space:]](.+)$ ]] && {
      fmt="${fmt//"%artist%"/${BASH_REMATCH[1]}}"
      continue
    }
    [[ $REPLY =~ ^Album:[[:space:]](.+)$ ]] && {
      fmt="${fmt//"%album%"/${BASH_REMATCH[1]}}"
      continue
    }
    [[ $REPLY =~ ^AlbumArtist:[[:space:]](.+)$ ]] && {
      fmt="${fmt//"%albumartist%"/${BASH_REMATCH[1]}}"
      continue
    }
    [[ $REPLY =~ ^Title:[[:space:]](.+)$ ]] && {
      fmt="${fmt//"%title%"/${BASH_REMATCH[1]}}"
      continue
    }
    [[ $REPLY =~ ^Track:[[:space:]](.+)$ ]] && {
      fmt="${fmt//"%track%"/${BASH_REMATCH[1]}}"
      continue
    }
    [[ $REPLY =~ ^Genre:[[:space:]](.+)$ ]] && {
      fmt="${fmt//"%genre%"/${BASH_REMATCH[1]}}"
      continue
    }
    [[ $REPLY =~ ^Date:[[:space:]](.+)$ ]] && {
      fmt="${fmt//"%date%"/${BASH_REMATCH[1]}}"
      continue
    }
    [[ $REPLY =~ ^Time:[[:space:]](.+)$ ]] && {
      fmt="${fmt//"%time%"/${BASH_REMATCH[1]}}"
      continue
    }
    [[ $REPLY =~ ^duration:[[:space:]](.+)$ ]] && {
      fmt="${fmt//"%duration%"/${BASH_REMATCH[1]}}"
      if [[ $search ]]; then 
        echo -e "$fmt"
        fmt="${1:-%artist% - %title%}"
        ((count++))
      else
        continue
      fi
    }
    [[ $REPLY =~ ^Pos:[[:space:]](.+)$ ]] && {
      fmt="${fmt//"%pos%"/$((BASH_REMATCH[1]+1))}"
      continue
    }
    [[ $REPLY =~ ^Id:[[:space:]](.+)$ ]] && {
      fmt="${fmt//"%id%"/${BASH_REMATCH[1]}}"
      echo -e "$fmt"
      fmt="${1:-%artist% - %title%}"
      ((count++))
    }
  done

  ((count==0)) && return 1 || return 0
}

getcurrent() {
  # display specific info about current song.
  # usage: getcurrent [format]
  # if no format is given, print URI.

  __is_mpd_running || return 1

  local fmt
  fmt="${1:-"%file%"}"

  cmd currentsong | __parse_song_info "$fmt"
}

getnext() {
  # display specific info about next song.
  # usage: getnext [format]
  # if no format is given, print URI.

  __is_mpd_running || return 1

  local fmt songid
  fmt="${1:-"%file%"}"

  songid="$(fcmd status nextsongid)"
  [[ $songid ]] || return 1
  cmd playlistid "$songid" | __parse_song_info "$fmt" 
}
