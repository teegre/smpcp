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
# M │ 2021/10/24
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
    uri="$(album_uri "$uri")"
    D1=$(
      while read -r; do
        date -d "${REPLY%% *}" "+%s"
      done < <(find_sticker "$uri" lastplayed 2> /dev/null) | max
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
# return a list of uri that matches given rating.
# usage: _db_get_uri_by_rating <rating>
# example: _db_get_uri_by_rating '>6' 2
# comparison operators are:
#  = equal, > greater, < lesser, >= greater or equal
#  <= lesser or equal, <> or != different

local val
val="$1"

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

if [[ $1 == "-l" ]]; then
  local order="ORDER BY RANDOM()"
  if [[ $2 =~ [[:digit:]]+ ]]; then
    local limit="LIMIT $2"
    shift 2
  else
    local count
    count="$(read_config song_mode_count)" || count=10
    local limit="LIMIT $count"
    shift
  fi
else
  local order="ORDER BY r.rating DESC, c.playcount DESC"
fi

sqlite3 "$SMPCP_STICKER_DB" << SQL
.timeout 2000
SELECT c.uri FROM (
  SELECT uri, CAST(value AS INTEGER) AS playcount FROM sticker
  WHERE name='playcount' AND playcount > 0
  ) AS c
  LEFT JOIN (
  SELECT uri, CAST(value AS INTEGER) AS rating FROM sticker
  WHERE name='rating' AND rating > 6
  ) AS r
  ON c.uri=r.uri
  WHERE r.rating IS NOT NULL
${order}
${limit};
SQL
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

notify_player "cleaning sticker database..."

message M "scanning sticker database."

local uris
local -a _orphans
local -a orphans
local t i=0 uri

mapfile -t uris < <(_db_get_all_songs)

((t=${#uris[@]}))

message M "found $t URI."
message M "done."
message M "processing."

for uri in "${uris[@]}"; do
  [[ $QUIET ]] || ((++i))
  [[ -a ${musicdir}/$uri ]] ||
    _orphans+=("\"${uri//\"/\\\"}\"")
  [[ $QUIET ]] ||
    printf "\r-- %d/%d: %d%%" $((i)) $((t)) $((i*100/t))
done

[[ $QUIET ]] || echo

message M "found ${#_orphans[@]} orphan(s)."

[[ ${_orphans[*]} ]] || {
  notify_player "sticker database is clean."
  return 0
}

# format list
for ((i=0;i<${#_orphans[@]}-1;i++)); do
  orphans+=("${_orphans[$i]}, ")
done

orphans+=("${_orphans[-1]}")

sqlite3 "$SMPCP_STICKER_DB" << SQL
.timeout 2000
DELETE FROM sticker
WHERE uri IN (${orphans[*]})
SQL

notify_player "sticker database cleaned in $(secs_to_hms $((EPOCHSECONDS-T)))"

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
    _is_in_playlist "$REPLY" && continue

    skipcount="$(get_sticker "$REPLY" skipcount 2> /dev/null)" ||
      skipcount=0

    ((skipcount>=skiplimit)) && continue

    if [[ $ALBUM ]]; then
      _is_in_history -a "$REPLY" && continue
    else
      _is_in_history "$REPLY" && continue
    fi

    echo "$REPLY"
    QUEUE+=("$REPLY")
    ((count++))
    ((count==$1)) && break
  done < <(shuf --random-source /dev/urandom "$SMPCP_SONG_LIST" 2> /dev/null)
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

  local RT R4 R5 C RR4 RR5
  RT="$(_db_rating_count "!=0")"
  R5="$(_db_rating_count "10")"
  R4="$(_db_rating_count "8")"
  
  ((C=count))
  ((RR5=C*R5/RT))

  logme "query: ***** $RR5"

  ((RR5>0)) && {
    get_uri_by_rating 10 $((RR5))
    r=$?
    ((count-=r))
  }

  ((RR4=C*R4/RT))

  logme "query: ****- $RR4"

  ((RR4>0)) && {
    get_uri_by_rating 8 $((RR4))
    r=$?
    ((count-=r))
  }

  logme "query: ----- $count"

  get_random_song $((count))

  ((C+count-RR5-RR4==0))

  logme "query: found $((C+(count-RR5-RR4))) song(s)."
}

get_fav() {
  # print random favourite songs
  _db_get_favourite -l
}
