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
# QUERY
# C │ 2021/04/05
# M │ 2021/04/09
# D │ Database query.

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
