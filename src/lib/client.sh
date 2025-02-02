# shellcheck shell=bash

#
# .▄▄ · • ▌ ▄ ·.  ▄▄▄· ▄▄·  ▄▄▄· super
# ▐█ ▀. ·██ ▐███▪▐█ ▄█▐█ ▌▪▐█ ▄█ music
# ▄▀▀▀█▄▐█ ▌▐▌▐█· ██▀·██ ▄▄ ██▀· player
# ▐█▄▪▐███ ██▌▐█▌▐█▪·•▐███▌▐█▪·• client
#  ▀▀▀▀ ▀▀  █▪▀▀▀.▀   ·▀▀▀ .▀    plus+
#
# This file is part of smpcp.
# Copyright (C) 2021-2025, Stéphane MEYER.
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
# M │ 2023/12/21
# D │ Basic MPD client.

declare SMPCP_SONG_LIST="$HOME/.config/smpcp/songlist"

is_mpd() {
  # check whether mpd is running or not.
  cmd ping &> /dev/null
}

__cmd() {
# send a command to music player daemon.
# usage: __cmd [-x] <command> [options]
# -x sets netcat buffering output delay time to 1 second.
# it prevents netcat from prematurely returning while 
# an expensive task is running (i.e listall).
#
# DO NOT USE THIS FUNCTION DIRECTLY. USE cmd INSTEAD.

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
  elif [[ $arg =~ ^.*[^\\][\"\|\']+.*$ ]]; then
    arg="${arg//\'/\\\'}"
    arg="${arg//\"/\\\"}"
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
  local _cmd _OK
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
    _OK=1
    [[ $REPLY ]] && echo "$REPLY"
  done < <(__cmd "$@")
  [[ $_OK ]] || return 1
}

fcmd() {
  # filter command output by printing value for a given key.
  # usage: fcmd [-c] [-x] <command> [options] <key[+key2+...+keyN]>
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

  [[ ${arglist[*]} ]] || {
    message E "fcmd: missing command or filter."
    return 1
  }

  local count=0

  while read -r; do
    [[ $REPLY =~ ^(${key//+/|}):[[:space:]](.+)$ ]] && {
      ((count++))
      if [[ $COUNT ]]; then
        continue
      else
        echo "${BASH_REMATCH[2]}"
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

parse_song_info() {
  # parse song information in the given format.
  #
  # available tags:
  #
  # %file% %ext% %last-modified% %format%
  # %artist% %name% %title% %album% %albumartist% %genre% %date%
  # %time% %duration%
  # %pos% %id%
  #
  # if tag cannot be parsed, it is stripped.
  # example: "now playing: %artist% - %title%"
  # if %artist% is not present we get: "now playing:  - Title"
  # to avoid this, use: "now playing:[[ %artist% -]] %title%"
  # and we get: "now playing: Title"

  [[ $1 == "-s" ]] && {
    local search=1
    shift
  }

  local fmt
  fmt="${1:-%file%}"

  strip_unexpanded() {
    # strip un-expanded tags from string.

    local src

    src="$1"

    local start=0 end=0
    while [[ $src =~ .*\[\[.*%.+%.*\]\].* ]]; do
      for ((i=start; i<${#src}; i++)); do
        char="${src:$i:1}"
        [[ $char == "[" ]] && [[ ${src:$((i+1)):1} == "[" ]] && ((start=i))
        [[ $char == "]" ]] && [[ ${src:$((i+1)):1} == "]" ]] && ((end=i+1))
        ((end>0)) && {
          sub="${src:$((start)):$((end-start+1))}"
          [[ $sub =~ .*%.+%.* ]] && {
            src="${src/"$sub"}"
            ((start=-1))
          }
          unset end
          ((start++))
          break
        }
      done
    done

    src="${src//\[\[}"
    src="${src//\]\]}"

    while [[ $src == *%*%* ]]; do
      [[ $src =~ .*(%.+%).* ]] &&
        src="${src/"${BASH_REMATCH[1]}"}"
    done

    echo -e "$src"
  }

  local count=0

  while IFS= read -r; do

    [[ $REPLY =~ ^file:[[:space:]](.+)$ ]] && {
      local filename="${BASH_REMATCH[1]}"
      fmt="${fmt//"%file%"/"$filename"}"
      fmt="${fmt//"%ext%"/"$(get_ext "$filename")"}"
      continue
    }
    [[ $REPLY =~ ^Last-Modified:[[:space:]](.+)$ ]] && {
      fmt="${fmt//"%last-modified%"/"${BASH_REMATCH[1]}"}"
      continue
    }
    [[ $REPLY =~ ^Format:[[:space:]](.+)$ ]] && {
      fmt="${fmt//"%format%"/"${BASH_REMATCH[1]}"}"
      continue
    }
    [[ $REPLY =~ ^Artist:[[:space:]](.+)$ ]] && {
      local artist
      artist="${BASH_REMATCH[1]}" # used as fallback for %albumartist%
      fmt="${fmt//"%artist%"/"$artist"}"
      continue
    }
    [[ $REPLY =~ ^Name:[[:space:]](.+)$ ]] && {
      fmt="${fmt//"%name%"/"${BASH_REMATCH[1]}"}"
      continue
    }
    [[ $REPLY =~ ^Album:[[:space:]](.+)$ ]] && {
      fmt="${fmt//"%album%"/"${BASH_REMATCH[1]}"}"
      continue
    }
    [[ $REPLY =~ ^AlbumArtist:[[:space:]](.+)$ ]] && {
      fmt="${fmt//"%albumartist%"/"${BASH_REMATCH[1]}"}"
      continue
    }
    [[ $REPLY =~ ^Title:[[:space:]](.+)$ ]] && {
      fmt="${fmt//"%title%"/"${BASH_REMATCH[1]}"}"
      continue
    }
    [[ $REPLY =~ ^Track:[[:space:]](.+)$ ]] && {
      fmt="${fmt//"%track%"/"${BASH_REMATCH[1]}"}"
      continue
    }
    [[ $REPLY =~ ^Genre:[[:space:]](.+)$ ]] && {
      fmt="${fmt//"%genre%"/"${BASH_REMATCH[1]}"}"
      continue
    }
    [[ $REPLY =~ ^Date:[[:space:]](.+)$ ]] && {
      fmt="${fmt//"%date%"/"${BASH_REMATCH[1]:0:4}"}"
      continue
    }
    [[ $REPLY =~ ^Disc:[[:space:]](.+)$ ]] && {
      fmt="${fmt//"%disc%"/"${BASH_REMATCH[1]}"}"
      continue
    }
    [[ $REPLY =~ ^Time:[[:space:]](.+)$ ]] && {
      fmt="${fmt//"%time%"/"${BASH_REMATCH[1]}"}"
      continue
    }
    [[ $REPLY =~ ^duration:[[:space:]](.+)$ ]] && {
      fmt="${fmt//"%duration%"/"${BASH_REMATCH[1]}"}"
      if [[ $search ]]; then
        [[ $fmt == *%albumartist%* ]] &&
          fmt="${fmt//%albumartist%/"$artist"}"
        echo -e "$(strip_unexpanded "$fmt")"
        fmt="${1:-%file%}"
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
      fmt="${fmt//"%id%"/"${BASH_REMATCH[1]}"}"
      [[ $fmt == *%albumartist%* ]] &&
        fmt="${fmt//%albumartist%/"$artist"}"
      [[ $filename =~ ^cdda: ]] && {
        [[ $fmt == *%title%* ]] && {
          local track
          track="${filename#*\/\/\/}"
          fmt="${fmt//%title%/"Track ${track}"}"
        }
        [[ $fmt == *%album%* ]] &&
          fmt="${fmt//%album%/"Audio CD"}"
      }
      strip_unexpanded "$fmt"
      fmt="${1:-%file%}"
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

  cmd currentsong | parse_song_info "$fmt"
}

get_next() {
  # display specific info about next song.
  # usage: get_next [format]
  # if no format is given, print URI.

  local fmt songid
  fmt="${1:-"%file%"}"

  songid="$(fcmd status nextsongid)"
  [[ $songid ]] || return 1
  cmd playlistid "$songid" | parse_song_info "$fmt" 
}

get_previous() {
  # display specific info about previous song.
  # usage: get_previous [format]
  # if no format is given, print URI.

  local fmt
  fmt="${1:-"%file%"}"

  if consume &> /dev/null; then
    is_daemon && {
      local index uri
      index="$(read_config history_index)" || index=0
      uri="$(_db_get_previous_song $((index)))"
      [[ $uri ]] &&
        cmd lsinfo "$uri" | parse_song_info -s "$fmt"
    }
  else
    local cid id
    cid="$(get_current "%id%")"
    ((id=cid-1))
    cmd playlistid "$id" 2> /dev/null | parse_song_info "$fmt"
  fi
}

get_info() {
  # display specific info about given URI.
  # usage: get_info <uri> <format>
  # print artist and title if no format.

  local uri
  uri="$1"
  shift

  local fmt
  fmt="${1:-"[[%artist% - ]]%title%"}"

  cmd lsinfo "$uri" | parse_song_info -s "$fmt"
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
album_uri() {
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

  local song_uri

  if [[ $1 ]]; then
    song_uri="$1"
    shift
  else
    song_uri="$(get_current)"
  fi

  # stream?
  [[ $song_uri =~ ^https?: ]] && {
    echo "${SMPCP_ASSETS}/radio.png"
    return
  }

  # audio cd?
  [[ $song_uri =~ ^cdda: ]] && {
    echo "${SMPCP_ASSETS}/audiocd.png"
    return
  }

  # is album art in cache directory?
  local albumhash albumart
  albumhash="$(get_info "$song_uri" "%albumartist%-%album%" | sha1sum | cut -d' ' -f 1)"
  albumart="${SMPCP_CACHE}/${albumhash}.jpg"

  [[ -a $albumart ]] && {
    echo "$albumart"
    return
  }

  local default musicdir
  default="$SMPCP_ASSETS/cover.jpg"

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
  uri="$(album_uri "$song_uri")"

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

  local uri
  uri="$(get_current)"

  if [[ $uri =~ ^https? ]] || [[ $uri =~ ^cdda: ]]; then
    message E "no info."
    return 1
  fi
  
  local info artist album albumartist date fmt
  mapfile -t info < <(get_current "%artist%\n%album%\n%albumartist%\n%date%") ||
    return 1

  artist="${info[0]}"
  album="${info[1]}"
  albumartist="${info[2]}"
  date="${info[3]}"

  if [[ $albumartist && $artist != "$albumartist" ]]; then
    local VA=1 # stands for various artists
    fmt="%track%→%artist%→%title%→%duration%"
  else
    fmt="%track%→%title%→%duration%"
  fi

  local uri tracklist count=0
  uri="$(album_uri)"
  while read -r; do
    ((++count))
    tracklist+=("$REPLY")
  done < <(cmd lsinfo "$uri" | parse_song_info -s "$fmt")

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
  # do it only if a database update previously occurred (expensive!).

  [[ -s $SMPCP_SONG_LIST ]] && {
    local list_mod_date db_mod_date
    list_mod_date="$(stat -t "$SMPCP_SONG_LIST" | cut -d' ' -f 13)"
    db_mod_date="$(fcmd stats db_update)"
    ((list_mod_date >= db_mod_date)) && return 1
  }
    
  [[ -t 1 ]] || notify_player "updating song list..."
  [[ -t 1 ]] && message M "updating song list..."

  local T="$EPOCHSECONDS"
  fcmd -x list file file > "$SMPCP_SONG_LIST"
  [[ -t 1 ]] && local D=$((EPOCHSECONDS-T))
  [[ -t 1 ]] || local D="$(sec_to_hms $((EPOCHSECONDS-T)))"

  [[ -t 1 ]] && message M "song list updated in ${D} seconds."
  [[ -t 1 ]] || notify_player "song list updated in ${D}."

  return 0
}

list_dir() {
  # print (sub)directory or file list relative to music_directory.
  # print partial matches.
  # usage: list_dir [uri]

  local musicdir dir _path

  musicdir="$(get_music_dir)" || return 1

  dir="$1"

  [[ $dir == ".." || $dir == "." ]] && unset dir

  local _path="${musicdir}/${dir}"

  if [[ -d $_path ]]; then
    [[ $_path == */ ]] || _path+="/"
  fi

  local f count=0 file

  for f in "$_path"*; do
    file="${f/${musicdir}\/}"
    [[ $file == *\* ]] && return 1
    [[ -d $f ]] && file+="/"
    ((++count))
    echo "$file"
  done

  if (( count > 0 )); then
    return 0
  else
    message E "nothing found."
    return 1
  fi
}

list_artists() {

 fcmd -x list albumartist AlbumArtist

}

list_albums() {
  
  local artist
  artist="$1"

  [[ $artist ]] || fcmd -x list album group albumartist Album
  [[ $artist ]] && fcmd -x list album "(AlbumArtist==$(_quote "$artist"))" Album
}

list_outputs() {
  # list available outputs

  [[ $1 == "-l" ]] && local NOSTATUS=1

  while read -r; do
    [[ $REPLY =~ ^outputname:[[:space:]](.+)$ ]] &&  {
      if [[ $NOSTATUS ]]; then
        echo "${BASH_REMATCH[1]}"
      else
        echo -n "${BASH_REMATCH[1]} "
      fi
    }
    [[ $REPLY =~ ^outputenabled:[[:space:]](.+)$ ]] && {
      if ! [[ $NOSTATUS ]]; then
        case ${BASH_REMATCH[1]} in
          0 ) echo "off" ;;
          1 ) echo "on" ;;
        esac
      fi
    }
  done < <(cmd outputs)
}

_get_output_id() {
  # print output id for <name>
  # usage: _get_output_id <name>

  local name line id

  name="$1"

  while read -r line; do
    [[ $line =~ ^outputid:[[:space:]](.+)$ ]] && id="${BASH_REMATCH[1]}"
    [[ $line =~ ^outputname:[[:space:]](.+)$ ]] &&
      [[ ${BASH_REMATCH[1]} == "$name" ]] && {
        echo "$id"
        return 0
      }
  done < <(cmd outputs)
  return 1
}

get_output_state() {
  local name line
  name="$1"
  while read -r line; do
    [[ $OK ]] && {
      [[ $line =~ ^outputenabled:[[:space:]](.+)$ ]] && {
        echo "${BASH_REMATCH[1]}"
        return 0
      }
    }
    [[ $line =~ ^outputname:[[:space:]](.+)$ ]] &&
      [[ ${BASH_REMATCH[1]} == "$name" ]] && local OK=1
  done < <(cmd outputs)
  return 1
}

set_output() {
 # enable/disable an output.
 # usage: set_output <name> [on|off]

  local name state id
  name="$1"
  state="$2"

  [[ $name ]] || {
    message E "missing output."
    return 1
  }

  id="$(_get_output_id "$name")" || {
    message E "'$1' no such output."
    return 1
  }

  case $state in
    on ) cmd enableoutput $((id))  || return 1 ;;
    off) cmd disableoutput $((id)) || return 1 ;;
    "" )
      state="$(get_output_state "$name")"
      ((state==0)) && state="off"
      ((state==1)) && state="on"
  esac

  message M "${name}: ${state}"

  return 0
}
