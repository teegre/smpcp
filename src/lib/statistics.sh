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
# STATISTICS
# C : 2021/04/08
# M : 2025/10/12
# D : Statistics management.

qdb_setup() {
  # local user password
  # user="$(read_config qdb_user)"
  # password="$(read_config qdb_password)"

  # if [[ $password =~ ^\$\((.+)\)$ ]]; then
  #   local cmd="${BASH_REMATCH[1]}"
  #   password="$($cmd)" 2> /dev/null  || {
  #     message E "invalid command."
  #     return 1
  #   }
  # elif [[ $password =~ ^\$\(.+[^\)]$ ]]; then
  #   message E "invalid password command."
  #   return 1
  # elif [[ $password =~ ^@\((.+)\)$ ]]; then
  #   password="$(echo "${BASH_REMATCH[1]}" | base64 -d)"
  # elif [[ $password =~ ^@\(.+[^\)]$ ]]; then
  #   message E "base64 password, invalid syntax."
  #   return 1
  # fi

  # [[ $password =~ ^\$\((.+)\) ]] && password="$("${BASH_REMATCH[1]}")"
  # SMPCP_QDB_USER="$user"
  # export SMPCP_QDB_USER
  # SMPCP_QDB_PWD="$password"
  # export SMPCP_QDB_PWD
  # unset user password

  qdb --quiet --nofield --log "${SMPCP_STICKER_DB}" open && return 0
  # No database... build it...  may take a while...
  local QDBCMDS="$(mktemp)"
  local ID=1
  logme "db:create"
  qdb --quiet --nofield "${SMPCP_STICKER_DB}" 'set lastbackup 0'
  qdb --quiet --nofield "${SMPCP_STICKER_DB}" 'set lastcompact 0'
  qdb --quiet --nofield "${SMPCP_STICKER_DB}" 'set lastupdate 0'
  notify_player "database created."
  local songcount="$(fcmd stats songs)"
  local percent=
  logme "db:process"
  notify_player "processing files..."
  while read -r; do
    percent=$((ID*100/songcount))
    (((songcount - ID) % (songcount / 10) == 0)) && notify_player "processing files...\n${percent}% done."
    local file="$(quote "${REPLY}")"
    local duration="$(get_duration "${REPLY}")"
    echo 'w @autoid(song) file "'"${file}"'" duration "'"${duration}"'"' >> $QDBCMDS
    echo 'w @autoid(fingerprint) song song:'${ID}' data n/a size 0' >> $QDBCMDS
    echo 'w @autoid(stat) song song:'${ID}' lastplayed 0 playcount 0 skipcount 0 rating 0' >> $QDBCMDS
    ((ID++))
  done < <(fcmd -x listall file | sort)

  echo "set lastupdate @now" >> $QDBCMDS

  logme "db:write"
  notify_player "writing to database..."
  qdb --quiet --pipe "${SMPCP_STICKER_DB}" < $QDBCMDS
  rm "$QDBCMDS"
  notify_player "all set!"
  logme "db:done"
  logme "db:session"

  qdb --quiet --nofield --log "${SMPCP_STICKER_DB}" open

  return 1
}

auto_compact() {
  # 
  local lastcompact now result
  qdb mpdmusic ping || return 1
  lastcompact="$(qdb mpdmusic 'get lastcompact')" || lastcompact=0
  now="$(_date "%s")"
  ((now-lastcompact >= 3600)) && {
    logme "compacting database..."
    qdb mpdmusic compact
    result=$?
    ((result == 0)) && { logme "done."; qdb mpdmusic 'set lastcompact @now'; }
    ((result == 1)) && logme "an error occured."
    return $result
  }
  return 1
}

auto_backup() {
  #
  local lastbackup now
  now="$(_date "%Y%m%d%H%M%S")"
  cp "${SMPCP_STICKER_DB}" "${SMPCP_STICKER_DB}.${now}.bak" 2> /dev/null && {
    qdb -q "${SMPCP_STICKER_DB}" "set lastbackup @now"
    return 0
  }
  return 1
}

quote() {
  local val="$1"
  val="${val//\"/\\\"}"
  val="${val//\'/\\\'}"
  echo $val
}

get_song_id() {
  local uri value

  [[ $@ ]] || uri="$(quote "$(get_current)")"
  [[ $@ ]] && uri="$(quote "$@")"

  [[ $uri =~ ^https?: ]] && return 1
  [[ $uri =~ ^cdda: ]] && return 1

  qdb mpdmusic ping 2> /dev/null || return 1

  export SONGID=$(qdb mpdmusic "id song file \"$uri\"" 2> /dev/null) && return 0
  return 1
}

get_sticker() {
  # OBSOLETE
  local uri name value ID
  uri="$1"

  [[ $uri =~ ^https?: ]] && return 1
  [[ $uri =~ ^cdda: ]] && return 1

  name="$2"
  [[ $uri && $name ]] && {
    get_song_id || return 1
    value="$(qdb mpdmusic 'q stat:'$SONGID' '"$name"'')" || return 1
    echo "$value"
    return 0
  }
  return 1
}

set_sticker() {
  # OBSOLETE
  local uri name value ID
  uri="$1"

  [[ $uri =~ ^https?: ]] && return 1
  [[ $uri =~ ^cdda: ]] && return 1

  name="$2"
  value="$3"

  [[ $uri && $name && $value ]] && {
    cmd sticker set song "$uri" "$name" "$value" || return 1
    return 0
  }
  return 1
}

find_sticker() {
  # OBSOLETE
  local uri name
  uri="$1"

  [[ $uri =~ ^https?: ]] && return 1
  [[ $uri =~ ^cdda: ]] && return 1

  name="$2"
  while read -r; do
    [[ $REPLY =~ ^sticker:[[:space:]]${name}=(.+)$ ]] &&
      echo "${BASH_REMATCH[1]}"
      local OK=1
  done < <(cmd sticker find song "$uri" "$name")
  [[ $OK ]] && return 0 || return 1
}

delete_sticker() {
  # OBSOLETE
  local uri name
  uri="$1"

  [[ $uri =~ ^https?: ]] && return 1
  [[ $uri =~ ^cdda: ]] && return 1

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

clear_media() { :> "/tmp/.currentmedia"; }

media_update() {
  is_mpd || {
    clear_media
    return
  }

  local fmt info
  fmt="[[%name% - ]][[%artist%: ]]%title%"
  info="$(get_current "$fmt")"
  info="${info:-$(get_current)}"

  echo "$(state -p):::${info}" > "/tmp/.currentmedia"
}

update_stats() {
  
  is_mpd || return 1

  [[ $1 == "--no-playcount" ]] && {
    local NO_PLAYCOUNT=1
    shift
  }

  local uri ID
  uri="$1"

  [[ $uri ]] || return 1

  [[ $uri =~ ^https?: ]] && return 0
  [[ $uri =~ ^cdda: ]] && return 0

  update_history_index

  get_song_id "$uri" || return 1

  # check audio fingerprint
  qdb mpdmusic 'q fingerprint:'${SONGID}' data=n/a' 2> /dev/null && {
    local file="$(quote "$uri")"
    local data="$(_get_fingerprint "$uri")"
    [[ -n $data ]] && {
      local fingerprint="$(echo "$data" | jq -r .fingerprint)"
      qdb mpdmusic 'w fingerprint:'${SONGID}' data "'"${fingerprint}"'" size "'"${#fingerprint}"'"'
    }
  }

  if [[ $NO_PLAYCOUNT ]]; then
    qdb mpdmusic 'w stat:'$SONGID' lastplayed @now' || return 1
  else
    qdb mpdmusic 'w stat:'$SONGID' lastplayed @now playcount @inc' || return 1
  fi
  return 0
}

reset_stats() {

  local uri ID
  uri=$1

  [[ $uri ]] || return 1

  get_song_id || return 1
  qdb mpdmusic 'w stat:'$SONGID' lastplayed 0 playcount 0 skipcount 0' || return 1

  return 0
}

rating() {
  # set current song rating.
  # usage: rating [uri] [value]
  # value must be an integer between 0 (unset) and 5.
  # if no given value, print actual rating.

  local uri

  if [[ $1 ]] && ! [[ $1 =~ ^[0-9]+$ ]]; then
    uri="$1"
    shift
  else
    uri="$(get_current)"
  fi

  get_song_id || return 1

  local cr
  cr="$(qdb mpdmusic 'q stat:'$SONGID' rating')" || cr=0
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

    qdb mpdmusic 'w stat:'$SONGID' rating '$((r*2))'' || return 1
    message M "$(get_current "%artist%: %title%") [$cr → $r]"
    return 0
  }
  message E "invalid value."
  return 1
}

# shellcheck disable=SC2120
lastplayed() {
  # print when song was last played.

  local uri ID

  if [[ $1 ]]; then
    uri="$1"
    shift
  else
    uri="$(get_current)"
  fi

  local lsp
  get_song_id || return 1
  qdb mpdmusic 'q stat:'$SONGID' @datetime(lastplayed)' || return 1
  return 0
  # lsp="$(get_sticker "$uri" @datetime(lastplayed))" || lsp="-"

  # echo "$lsp"
}

# shellcheck disable=SC2120
playcount() {
  # print song playcount.

  local uri ID

  if [[ $1 ]]; then
    uri="$1"
    shift
  else
    uri="$(get_current)"
  fi

  get_song_id || return 1
  qdb mpdmusic 'q stat:'$SONGID' playcount' || return 1
  return 0
}

# shellcheck disable=SC2120
skipcount() {
  # print song skipcount.

  local uri

  if [[ $1 ]]; then
    uri="$1"
    shift
  else
    uri="$(get_current)"
  fi

  get_song_id || return 1
  qdb mpdmusic 'q stat:'$SONGID' skipcount' || return 1
  return 0
}

# shellcheck disable=SC2119
song_stats() {
  # print current song statistics.
  local uri ID
  uri="$(get_current)"
  get_current "[[%name%\n]][[%artist%: ]]%title%[[\n%album%]][[ (%date%)]]"
  echo "$(get_elapsed -h) / $(get_duration -h)"

  if [[ $uri =~ ^https?: ]] || [[ $uri =~ ^cdda: ]]; then
    return
  fi

  local R r L P S
  get_song_id || return 1
  IFS='|' read R L P S < <(qdb mpdmusic 'q stat:'$SONGID' rating:@datetime(lastplayed):playcount:skipcount')

  [[ $L =~ ^1970 ]] && L="-"

 ((R/=2))

  case $R in
    0) r="-----" ;;
    1) r="*----" ;;
    2) r="**---" ;;
    3) r="***--" ;;
    4) r="****-" ;;
    5) r="*****"
  esac

  echo "===="
  echo "rating:      ${r}"
  echo "last played: ${L}"
  echo "play count:  ${P}"
  echo "skip count:  ${S}"
}

show_stats() {
  local k v
  while read -r; do
    [[ $REPLY =~ ^(.+):[[:space:]](.+)$ ]] && {
      k="${BASH_REMATCH[1]}"
      v="${BASH_REMATCH[2]}"

      [[ $1 ]] && {
        [[ $1 == $k ]] || continue
        # if a key is given do not print.
      }

      [[ $1 ]] || echo -n "${k}: "

      case $k in
        uptime) secs_to_hms $((v)); echo ;;
        playtime) secs_to_hms $((v)); echo ;;
        db_playtime) secs_to_hms $((v)); echo ;;
        db_update) _date "%Y/%m/%dT%H:%M:%S" $((v)); echo ;;
        update) secs_to_hms $((v)); echo ;;
        *) echo "$v"

      esac
      # exit loop if key was found.
      [[ $1 == $k ]] && break
    }
  done < <(cmd stats)
}
