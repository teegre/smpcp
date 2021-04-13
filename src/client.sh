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
# CLIENT
# C │ 2021/04/02
# M │ 2021/04/13
# D │ Basic MPD client.

__is_mpd_running() {
  # check whether mpd is running or not.

  local pidfile="$HOME/.config/mpd/pid"
  local pid
  [[ -s $pidfile ]] && {
    pid="$(<"$pidfile")"
    check_pid "$pid" && return 0
  }
  __msg E "mpd PID file not found."
  return 1
}

__cmd() {
# send a command to music player daemon.
# usage: __cmd [-x] <command> [options]
# -x sets the buffering output delay time (source: netcat manpage) to 1 second.
# it prevents netcat from prematurely returning when an expensive task is running
# (i.e listall).

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
    idle    ) shift; idlecmd "$@" ;;
    idleloop) shift; idlecmd loop "$@" ;;
    *       ) echo "ACK [] {} invalid command."
  esac
  return $?
fi

# preserve quoted arguments.
local arg arglist
for arg in "${@}"; do
  # whitespace separated string: assuming double quotes are escaped.
  if [[ $arg =~ ^.*[[:space:]]+.* ]]; then
    arglist+=("\"${arg}\"")
  # no whitespace string: quote and escape.
  elif [[ $arg =~ ^.*[\"\|\']+.*$ ]]; then
    arg="${arg//\'/\\\'}"
    arg="${arg//\"/\\\"}"
    arglist+=("\"$arg\"")
  else
    arglist+=("$arg")
  fi
done

# __msg M "arglist: ${arglist[*]}"

${nccmd} << CMD
${arglist[@]:-}
close
CMD

}

cmd() {
  # like __cmd + filter errors.
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

get_current() {
  # display specific info about current song.
  # usage: get_current [format]
  # if no format is given, print URI.

  local fmt
  fmt="${1:-"%file%"}"

  cmd currentsong | __parse_song_info "$fmt"
}

get_next() {
  # display specific info about next song.
  # usage: get_next [format]
  # if no format is given, print URI.

  local fmt songid
  fmt="${1:-"%file%"}"

  songid="$(fcmd status nextsongid)"
  [[ $songid ]] || return 1
  cmd playlistid "$songid" | __parse_song_info "$fmt" 
}

get_duration() {
  # get song duration in seconds.
  # usage: get_duration [-h] [uri]
  # -h print time in a human readable format.

  local duration
  duration="$(fcmd status duration)"
  duration="${duration%%.*}"

  [[ $duration ]] || return 1

  [[ $1 ]] || { echo "$duration"; return; }

  [[ $1 == "-h" ]] && {
    ((duration>3600)) && {
      TZ=UTC _date "%H:%M:%S" $((duration))
      echo
      return
    }
    TZ=UTC _date "%M:%S" $((duration))
    echo
    return
  }
  return 1
}

get_elapsed() {
  # get current song elapsed time in seconds.
  # usage: getelapsed [-h]
  # -h print time in a human readable format.

  local elapsed
  elapsed="$(fcmd status elapsed)"
  elapsed="${elapsed%%.*}"

  [[ $elapsed ]] || return 1

  [[ $1 ]] || { echo "$elapsed"; return; }

  [[ $1 == "-h" ]] && {
    local duration
    duration="$(fcmd status duration)"
    duration="${duration%%.*}"
    ((duration>3600)) && {
      TZ=UTC _date "%H:%M:%S" $((elapsed))
      echo
      return
    }
    TZ=UTC _date "%M:%S" $((elapsed))
    echo
    return
  }
  return 1
}

get_albumart() {

  # is album art in cache directory?
  local albumart
  albumart="$(getcurrent "%album%" | shasum | cut -d' ' -f 1)"
  albumart="${SMPCP_CACHE}/${albumart}.jpg"

  [[ -a $albumart ]] && {
    echo "$albumart"
    return
  }

  local default musiclib
  default="$HOME/projets/smpcp/cover.jpg"
  musiclib="$(read_config music_library)" || unset musiclib

  [[ $musiclib ]] || {
    echo "$default"
    return
  }

  musiclib="${musiclib/\~/$HOME}"

  local covers cover album_uri album
  album_uri="$(getcurrent)"
  album_uri="${album_uri%/*}"
  album="${musiclib}/$album_uri"

  mapfile -t covers < <(find "$album" -name 'cover.*')

  [[ ${covers[*]} ]] || {
    echo "$default"
    return
  }

  if [[ ${#covers[@]} -gt 1 ]]; then
    cover="${covers[0]}"
  else
    cover="${covers[*]}"
  fi

  convert "$cover" -resize 64x64 "$albumart" &> /dev/null || {
    echo "$default"
    return
  }

  echo "$albumart"
}
