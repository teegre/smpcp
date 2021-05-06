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
# M │ 2021/05/05
# D │ Basic MPD client.

declare SMPCP_SONG_LIST="$HOME/.config/smpcp/songlist"

__is_mpd_running() {
  # check whether mpd is running or not.

  local pidfile="$HOME/.config/mpd/pid"
  local pid
  [[ -s $pidfile ]] && {
    pid="$(<"$pidfile")"
    check_pid "$pid" && return 0
  }
  return 1
}

__cmd() {
# send a command to music player daemon.
# usage: __cmd [-x] <command> [options]
# -x sets netcat buffering output delay time to 1 second.
# it prevents netcat from prematurely returning while 
# an expensive task is running (i.e listall).
#
# DON'T USE THIS. USE cmd INSTEAD.

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

# message M "$*"

# preserve quoted arguments.
local arg arglist
for arg in "${@}"; do
  # whitespace separated string: assuming double quotes are escaped.
  if [[ $arg =~ ^.*[[:space:]]+.* ]]; then
    arglist+=("\"${arg}\"")
  # no whitespace string: quote and escape.
  elif [[ $arg =~ ^.*[^\\][\"\|\']+.*$ ]]; then
    arg="${arg//\'/\\\'}"
    arg="${arg//\"/\\\"}"
    arglist+=("\"$arg\"")
  else
    arglist+=("$arg")
  fi
done

# message M "arglist: ${arglist[*]}"

${nccmd} << CMD
${arglist[@]:-}
close
CMD

}

cmd() {
  # like __cmd + filter errors.
  local _cmd
  _cmd="$*"
  while read -r; do
    [[ $REPLY =~ ^OK.+$ ]] && continue
    [[ $REPLY == "OK" ]] && return 0
    [[ $REPLY =~ ^ACK[[:space:]]\[.*\][[:space:]]\{.*\}[[:space:]](.+)$ ]] && {
      [[ ${FUNCNAME[-2]} == "loop" && $_cmd != "config" ]] &&
        logme "[ERROR] ${BASH_REMATCH[1],,}\ncommand: ${_cmd}\nfunctions: ${FUNCNAME[*]}"
      message E "${BASH_REMATCH[1],,}"
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
  # or the last option is the key.
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

# shellcheck disable=SC2120
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

_parse_song_info() {
  # parse song information in the given format.
  #
  # available tags:
  #
  # %file% %last-modified% %format%
  # %artist% %name% %title% %album% %albumartist% %genre% %date%
  # %time% %duration%
  # %pos% %id%

  [[ $1 == "-s" ]] && {
    local search=1
    shift
  }

  local fmt
  fmt="${1:-%artist% - %title%}"

  strip_unexpanded() {
    # strip un-expanded tags from string.

    local source str i w dest
    
    source="$1"

    [[ $source == *%*%* ]] || { echo "$source"; return; }

    # FIXME: "A B  C D" becomes "A B C D"
    IFS=$'\n' read -d "" -ra str <<< "${source// /$'\n'}"
    for ((i==0;i<${#str[@]};i++)); do
      w="${str[$i]}"
      [[ $w =~ ^%.+%(.*)$ ]] && {
        dest+="${BASH_REMATCH[1]}"
        continue
      }
      ((i==0)) && dest+="$w"
      ((i>0)) && dest+=" $w"
    done

    echo "$dest"
  }

  local count=0

  while IFS= read -r; do

    [[ $REPLY =~ ^file:[[:space:]](.+)$ ]] && {
      fmt="${fmt//"%file%"/"${BASH_REMATCH[1]}"}"
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
    [[ $REPLY =~ ^Name:[[:space:]](.+)$ ]] && {
      fmt="${fmt//"%name%"/${BASH_REMATCH[1]}}"
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
      fmt="${fmt//"%date%"/${BASH_REMATCH[1]:0:4}}"
      continue
    }
    [[ $REPLY =~ ^Time:[[:space:]](.+)$ ]] && {
      fmt="${fmt//"%time%"/${BASH_REMATCH[1]}}"
      continue
    }
    [[ $REPLY =~ ^duration:[[:space:]](.+)$ ]] && {
      fmt="${fmt//"%duration%"/${BASH_REMATCH[1]}}"
      if [[ $search ]]; then 
        echo -e "$(strip_unexpanded "$fmt")"
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
      echo -e "$(strip_unexpanded "$fmt")"
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

  cmd currentsong | _parse_song_info "$fmt"
}

get_next() {
  # display specific info about next song.
  # usage: get_next [format]
  # if no format is given, print URI.

  local fmt songid
  fmt="${1:-"%file%"}"

  songid="$(fcmd status nextsongid)"
  [[ $songid ]] || return 1
  cmd playlistid "$songid" | _parse_song_info "$fmt" 
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
      secs_to_hms $((duration))
      echo
      return
  }
  return 1
}

get_elapsed() {
  # get current song elapsed time in seconds.
  # usage: get_elapsed [-h]
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
    secs_to_hms $((elapsed))
    echo
    return
  }
  return 1
}

# shellcheck disable=SC2120
_album_uri() {
  # print current album URI.

  local uri

  [[ $1 ]] && uri="$1" || uri="$(get_current)"
  uri="${uri%/*}"

  echo "$uri"

  [[ $uri ]] && return 0 || return 1
}

get_music_dir() {
  # locate music directory.

  local musicdir
  musicdir="$(fcmd config music_directory 2> /dev/null)" ||
    musicdir="$(read_config music_directory)" ||
      return 1
  echo "$musicdir"
  return 0
}

get_albumart() {

  # is album art in cache directory?
  local albumart
  albumart="$(get_current "%album%" | sha1sum | cut -d' ' -f 1)"
  albumart="${SMPCP_CACHE}/${albumart}.jpg"

  [[ -a $albumart ]] && {
    echo "$albumart"
    return
  }

  local default musicdir
  default="$SMPCP_ASSETS/cover.jpg"

  # stream?
  [[ $(get_current) =~ ^http ]] && {
    echo "$default"
    return
  }

  # locate music directory.
  musicdir="$(get_music_dir)" || {
    echo "$default"
    return
  }

  # expand ~ if needed.
  [[ $musicdir =~ ^~.*$ ]] &&
    musicdir="${musicdir/\~/"$HOME"}"

  # remove trailing /
  musicdir="${musicdir%*/}"

  # does directory exists?
  [[ -d $musicdir ]] || {
    echo "$default"
    return
  }

  local uri covers cover
  uri="$(_album_uri)"

  mapfile -t covers < <(fcmd listfiles "$uri" file | grep '^cover\..*$\|^folder\..*$')

  [[ ${covers[*]} ]] || {
    echo "$default"
    return
  }

  if [[ ${#covers[@]} -gt 1 ]]; then
    cover="${covers[0]}"
  else
    cover="${covers[*]}"
  fi

  convert "${musicdir}/${uri}/$cover" -resize 64x64 "$albumart" &> /dev/null || {
    echo "$default"
    return 1
  }

  echo "$albumart"
}

get_album_info() {
  # print current album full info.
  
  local info artist album albumartist date fmt
  mapfile -t info < <(get_current "%artist%\n%album%\n%albumartist%\n%date%") ||
    return 1

  artist="${info[0]}"
  album="${info[1]}"
  albumartist="${info[2]}"
  date="${info[3]}"

  if [[ $albumartist != "%albumartist%" && $artist != "$albumartist" ]]; then
    local VA=1 # stands for various artists
    fmt="%track%→%artist%→%title%→%duration%"
  else
    fmt="%track%→%title%→%duration%"
  fi

  local uri tracklist count=0
  uri="$(_album_uri)"
  while read -r; do
    ((++count))
    tracklist+=("$REPLY")
  done < <(cmd lsinfo "$uri" | _parse_song_info -s "$fmt")

  local t song track title dur=0
  for t in "${tracklist[@]}"; do
    IFS=$'\n' read -d "" -ra song <<< "${t//→/$'\n'}"
    track="${song[0]}"
    if [[ $VA ]]; then
      artist="${song[1]}"
      title="${song[2]}"
      duration="${song[3]%%.*}"
    else
      title="${song[1]}"
      duration="${song[2]%%.*}"
    fi

    ((dur+=duration))

    [[ $VA ]] ||
      printf "%0${#count}d. │ %s │ %s\n" $((track)) "$(secs_to_hms $((duration)))" "$title"
    [[ $VA ]] &&
      printf "%0${#count}d. │ %s │ %s: %s\n" $((track)) "$(secs_to_hms $((duration)))" "$artist" "$title"
  done

  local trk
  ((count>1)) && trk="tracks" || trk="track"
  echo "---"
  [[ $VA ]] && artist="$albumartist"
  [[ $date ]] && echo "${artist}: ${album} ($date)"
  [[ $date ]] || echo "${artist}: ${album} (n/a)"
  echo "$((count)) $trk - $(secs_to_hms $((dur)))"
}

_quote() {
  # set appropriate quoting for filter argument.
  # usage: _quote <argument>
  local arg
  arg="$1"
  # Symphonie n° 6 "Pastorale"
  if [[ $arg =~ ^.*[[:space:]]+\".+\".*$ ]]; then
    arg="'${arg//\"/\\\"}'"
  # The Man Machine
  elif [[ $arg =~ ^.*[[:space:]]+.* ]]; then
    arg="\\\"${arg}\\\""
  # "Heroes"
  elif [[ $arg =~ ^\".+\"$ ]]; then
    arg="'${arg}'"
  else
    arg="\"${arg}\""
  fi
  echo "$arg"
}

get_discography() {
  # print artist discography

  local artist count=0
  [[ $1 ]] && artist="$1" ||
    artist="$(get_current "%artist%")" || return 1

  # shellcheck disable=SC2119
  [[ $artist ]] || state || return 1

  local album date
  while read -r; do
    ((++count))
    album="$REPLY"
    date="$(fcmd list date "(album==$(_quote "$REPLY"))" Date)"
    [[ $date ]] && echo "$album (${date:0:4})"
    [[ $date ]] || echo "$album"
  done < <(fcmd list album "(artist==$(_quote "$artist"))" Album)

  local duration songcount
  duration="$(fcmd count "(artist==$(_quote "$artist"))" playtime)"
  songcount="$(fcmd count "(artist==$(_quote "$artist"))" songs)"

  local alb sng
  echo "---"
  ((count>1)) && alb="albums" || alb="album"
  ((songcount>1)) && sng="songs" || sng="song"
  echo "$artist - $count ${alb} / ${songcount} ${sng}."
  echo "Total playtime: $(secs_to_hms "$duration")"

}

update_song_list() {
  # make a text file containing all songs to ease playlist generation.
  # do it only if needed (expensive!).

  [[ -s $SMPCP_SONG_LIST ]] && {
    local list_mod_date db_mod_date
    list_mod_date="$(stat -t "$SMPCP_SONG_LIST" | cut -d' ' -f 13)"
    db_mod_date="$(fcmd stats db_update)"
    ((list_mod_date >= db_mod_date)) && return 1
  }
    
  fcmd -x list file file > "$SMPCP_SONG_LIST"
  return 0
}
