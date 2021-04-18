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
# QUERY
# C │ 2021/04/05
# M │ 2021/04/18
# D │ Database query.

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

  cmd search "$@" | _parse_song_info -s "$fmt" ||
    return 1
}

searchadd() {
  # case insensitive search + add result to queue.
  # usage: searchadd <tag> <value> [... <tag> <value>]

  cmd searchadd "$@"
}

update() {
  # update database.
  # usage: update [uri]

  cmd update "$@"
}

_is_in_history() {
  # return whether a song/album is in history.
  # usage: _is_in_history [-a] <uri> 
  # exit status:
  # 0 true
  # 1 false
  
  [[ $1 == "-a" ]] && { local ALBUM=1; shift; }
  local uri dur D1 D2
  uri="$1"
  dur="$(read_config keep_in_history)" || return 1
  
  if [[ $ALBUM ]]; then
    D1=$(
      while read -r; do
        date -d "${REPLY%% *}" "+%s"
      done < <(find_sticker "$uri" lastplayedi 2> /dev/null) | _max
    )
  else
    D1="$(get_sticker "$uri" lastplayed 2> /dev/null)"
    D1="$(date -d "${D1%% *}" "+%s")"
  fi

  [[ $D1 ]] || return 1

  D2="$(date -d "now -${dur}" "+%s")"

  ((D1 >= D2)) && return 0 || return 1
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

local val
val="$1"

[[ $val =~ ^[0-9]+ ]] && val="=$val"

sqlite3 "$SMPCP_STICKER_DB" << SQL
.timeout 2000
SELECT COUNT(uri) FROM sticker
WHERE name="rating" AND value${val};
SQL
}

_db_get_uri_by_rating() {
# return a list of (count) uri that matches given rating.
# usage: _db_get_uri_by_rating <rating> <count>
# example: _db_get_uri_by_rating '>6' 2
# comparison operators are:
#  = equal, > greater, < lesser, >= greater or equal
#  <= lesser or equal, <> or != different

local val count
val="$1"
count="$2"

[[ $val =~ ^[0-9]+ ]] && val="=$val"

sqlite3 "$SMPCP_STICKER_DB" << SQL
.timeout 2000
SELECT uri FROM sticker
WHERE name="rating" AND value${val}
ORDER BY Random();
SQL
}

get_uri_by_rating() {
  # filters _db_get_uri_by_rating and
  # check lastplayed and skipcount values to
  # determine if the song is ok to be added 
  # to the queue.
  # exit status:
  # 0 no item was found.
  # >0 the number of items found.
  
  local count=0 skiplimit skipcount
  skiplimit="$(read_config skip_limit)" || skiplimit=0
  
  while read -r; do
    skipcount="$(get_sticker "$REPLY" skipcount 2> /dev/null)" ||
      skipcount=0

    ((skipcount>=skiplimit)) && continue
    _is_in_history "$REPLY" && continue
    _is_in_playlist "$REPLY" && continue

    echo "$REPLY"
    QUEUE+=("$REPLY")
    ((count++))
    ((count==$2)) && break
  done < <(_db_get_uri_by_rating "$1")

  return $((count))
}

_db_get_history() {

local hlen from
hlen="$(read_config keep_in_history)"
from="$(date -d "now -$hlen" "+%F %T")"

sqlite3 "$SMPCP_STICKER_DB" << SQL
.timeout 2000
SELECT datetime(value) AS d, uri
FROM sticker
WHERE name="lastplayed" AND value BETWEEN "${from}" AND "$(now)"
ORDER BY d DESC;
SQL
}

get_random_song() {
  # print random song(s).

  local count=0 skiplimit skipcount

  [[ $1 == "-a" ]] && {
    local ALBUM=1
    shift
  }

  skiplimit="$(read_config skip_limit)" || skiplimit=0

  while read -r; do
    skipcount="$(get_sticker "$REPLY" skipcount 2> /dev/null)" ||
      skipcount=0

    ((skipcount>=skiplimit)) && continue
    if [[ $ALBUM ]]; then
      _is_in_history -a "$REPLY" && continue
    else
      _is_in_history "$REPLY" && continue
    fi
    _is_in_playlist "$REPLY" && continue

    echo "$REPLY"
    QUEUE+=("$REPLY")
    ((count++))
    ((count==$1)) && break
  done < <(shuf "$SMPCP_SONG_LIST" 2> /dev/null)
}

get_rnd() {
  # print random songs / albums
  local count r

  [[ $1 == "-a" ]] && {
    local ALBUM=1
    shift
  }
  
  count=$1

  mapfile -t QUEUE < <(list_queue -f 2> /dev/null)

  [[ $ALBUM ]] && {
    local uri
    uri="$(get_random_song -a "$count")"
    uri="$(_album_uri "$uri")"
    echo "$uri"
    return
  }

  local RT R4 R5 C RR4 RR5
  RT="$(_db_rating_count "!=0")"
  R5="$(_db_rating_count "10")"
  R4="$(_db_rating_count "8")"
  
  ((C=count))
  ((RR5=C*R5/RT))
  get_uri_by_rating 10 $((RR5))
  r=$?
  ((count-=r))

  ((RR4=C*R4/RT))
  get_uri_by_rating 8 $((RR4))
  r=$?
  ((count-=r))

  get_random_song $((count))
}
