# shellcheck shell=baa$h

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
# QUERY
# C │ 2021/04/05
# M │ 2023/09/05
# D │ Music and sticker database query + related utilities.

# to achieve some advanced search we need to directly query
# the sticker database.
declare SMPCP_STICKER_DB
SMPCP_STICKER_DB="$(read_config sticker_db)"

declare -a QUEUE

search() {
  # case insensitive search in the database.
  # usage: search [-p] <tag> <value> [... <tag> <value>]
  # if -p is used, print track artist title album and date,
  # print file otherwise.

  local fmt

  if [[ $1 == "-p" ]]; then
    fmt="%track%. %artist%: %title% | %album% (%date%)"
    shift
  else
    fmt="%file%"
  fi

  cmd -x search "$@" | parse_song_info -s "$fmt" ||
    return 1
}

searchadd() {
  # case insensitive search + add result to queue.
  # usage: searchadd <tag> <value> [... <tag> <value>]

  cmd -x searchadd "$@"
}

update() {
  # update database.
  # usage: update [uri]

  cmd update "$@"
}

_is_in_playlist() {
  # check whether a song or artist is
  # already in the queue.
  # exit status:
  #  0 true
  #  1 false
  local uri="$1" song A1 A2
  for song in "${QUEUE[@]}"; do
    [[ $uri == "$song" ]] && return 0
    A1="$(fcmd lsinfo "$uri" Artist)"
    A2="$(fcmd lsinfo "$song" Artist)"
    [[ $A1 == "$A2" ]] && return 0
  done
  return 1
}

_db_rating_count() {
# return item count that matches given rating.
# usage: _db_rating_count <rating>
# example: db_rating_count '10'
# comparison operators are:
#  = equal, > greater, < lesser, >= greater or equal
#  <= lesser or equal, <> or != different
  return 0
}

_db_get_history() {
  qdb mpdmusic ping 2> /dev/null || return 1
  local hlen from
  hlen="$(read_config keep_in_history)"
  from="$(date -d "now -$hlen" "+%s")"

  [[ $1 == -h ]] && \
    qdb mpdmusic 'Q stat #lastplayed>'$from':--@datetime(lastplayed) song:file'
  [[ $1 == -h ]] || \
    qdb mpdmusic 'Q stat --lastplayed>'$from' song:file'
}

_db_get_previous_song() {
  # print a song URI from history.
  # usage: _db_get_previous_song [index]

  local index i=0
  index="${1:-0}"

  while read -r; do
    ((i==index)) && {
      [[ $REPLY =~ ^.*\|(.+)$ ]] && {
        echo "${BASH_REMATCH[1]}"
        return 0
      }
    }
    ((i++))
  done < <(_db_get_history 2> /dev/null)
  return 1
}

_db_get_all_songs() {

sqlite3 "$SMPCP_STICKER_DB" << SQL
.timeout 2000
SELECT uri FROM sticker
GROUP BY uri
ORDER BY uri ASC;
SQL
}


_db_get_favourite() {
# return favourite songs.
# usage: _db_get_favourite [-l [count]]
# without option, it returns all favourite songs, 
# that is, most played songs with a rating greater than 3,
# most played on top of the list.
# if '-l' option is provided it limits the number of songs
# to 'song_mode_count' configuration parameter or to the 
# number entered, if any.

 return 0
}

clean_orphan_stickers() {
# check for orphans and remove them from
# sticker database.
#
# NOTE: when a file is removed physically and from the database, 
# its stats remain in the sticker database. Hence this function.
# But when a file is renamed or moved, it would be great to
# keep its stats in the sticker database and only update its uri...
# it would imply storing some unique id for each file...

  qdb mpdmusic ping 2> /dev/null || return 1

  [[ $1 == "-q" ]] && {
    shift
    local QUIET=1
  }

  local musicdir

  musicdir="$(get_music_dir)" || {
    message E "could not find music directory."
    return 1
  }

  local T="$EPOCHSECONDS"

  [[ -t 1 ]] && message M "cleaning sticker database..."
  [[ -t 1 ]] || notify_player "cleaning sticker database..."

  message M "scanning sticker database."

  local uris
  local -a _orphans
  local -a orphans
  local t i=0 uri

  mapfile -t uris < <(qdb mpdmusic 'q song file' | sort)

  ((t=${#uris[@]}))

  message M "found $t URI."
  message M "done."
  message M "processing."

  for uri in "${uris[@]}"; do
    [[ $QUIET ]] || ((++i))
    [[ -a ${musicdir}/$uri ]] ||
      _orphans+=("'${uri//\'/\'\'}'")
    [[ $QUIET ]] ||
      printf "\r-- %d/%d: %d%%" $((i)) $((t)) $((i*100/t))
  done

  [[ $QUIET ]] || echo

  message M "found ${#_orphans[@]} orphan(s)."

  [[ ${_orphans[*]} ]] || {
    [[ -t 1 ]] && message M "sticker database is clean."
    [[ -t 1 ]] || notify_player "sticker database is clean."
    return 0
  }

  # format list
  for ((i=0;i<${#_orphans[@]}-1;i++)); do
    orphans+=("${_orphans[$i]},")
  done

  orphans+=("${_orphans[-1]}")

  qdb mpdmusic 'qq stat song:file('${orphans[*]}')'
  qdb mpdmusic 'hdel @recall(stat)'
  qdb mpdmusic 'qq fingerprint song:file('${orphans[*]}')'
  qdb mpdmusic 'hdel @recall(fingerprint)'
  qdb mpdmusic 'qq song file('${orphans[*]}')'
  qdb mpdmusic 'hdel @recall(song)'

  [[ -t 1 ]] && message M "sticker database cleaned in $(secs_to_hms "$((EPOCHSECONDS-T))")."
  [[ -t 1 ]] || notify_player "sticker database cleaned in $(secs_to_hms "$((EPOCHSECONDS-T))")."

}

get_random_song() {
  # print random song(s).
  qdb mpdmusic ping 2> /dev/null || return 1

  local count=0 skiplimit tracks

  local dur="$(read_config keep_in_history)"
  local D="$(date -d "now -${dur}" "+%s")"

  [[ $1 == "-a" ]] && {
    local ALBUM=1
    shift
  }

  skiplimit="$(read_config skip_limit)" || skiplimit=3

  [[ $ALBUM ]] && tracks=100
  [[ $ALBUM ]] || tracks=$(($1<10?100:$1**2))

  while read -r; do
    _is_in_playlist "$REPLY" && continue

    echo "$REPLY"
    QUEUE+=("$REPLY")
    ((count++))
    ((count==$1)) && break
  done < <(qdb mpdmusic 'Q song?!'$((tracks))' file stat:#lastplayed<'$D':#skipcount<'$skiplimit'' 2> /dev/null)
}

get_rnd() {
  # print random songs / albums
  local count r

  [[ $1 == "-a" ]] && {
    local ALBUM=1
    shift
  }
  
  count=$1
  [[ $count ]] || {
    count="$(read_config song_mode_count)" || count=10
  }

  mapfile -t QUEUE < <(list_queue -f 2> /dev/null)

  logme "query: queue length: $(queue_length)"

  [[ $ALBUM ]] && {

    logme "query: $((count)) album(s)."

    while read -r; do
      album_uri "$REPLY"
    done < <(get_random_song -a $((count)))
    return
  }

  # local RT R4 R5 C RR4 RR5
  # RT="$(_db_rating_count "!=0")"
  # R5="$(_db_rating_count "10")"
  # R4="$(_db_rating_count "8")"
  
  ((C=count))
  # ((RR5=C*R5/RT))

  # logme "query: ***** $RR5"

  # ((RR5>0)) && {
  #   get_uri_by_rating 10 $((RR5))
  #   r=$?
  #   ((count-=r))
  # }

  # ((RR4=C*R4/RT))

  # logme "query: ****- $RR4"

  # ((RR4>0)) && {
    # get_uri_by_rating 8 $((RR4))
    # r=$?
    # ((count-=r))
  # }

  logme "query: ----- $count"

  get_random_song $((count))

  # ((C+count-RR5-RR4==0))

  # logme "query: found $((C+(count-RR5-RR4))) song(s)."
  logme "query: found $((count)) song(s)."
}

get_fav() {
  # print random favourite songs
  _db_get_favourite -l
}
