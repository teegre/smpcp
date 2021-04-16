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
# M │ 2021/04/16
# D │ Database query.

declare SMPCP_STICKER_DB
SMPCP_STICKER_DB="$(read_config sticker_db)"

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

  cmd search "$@" | __parse_song_info -s "$fmt" ||
    return 1
}

searchadd() {
  # case insensitive search + add result to queue.
  # usage: searchadd <tag> <value> [... <tag> <value>]

  cmd searchadd "$@"
}

_db_rating_count() {
# return item count that matches rating criteria.
# usage: _db_rating_count <criteria>
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

