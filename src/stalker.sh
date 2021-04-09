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
# STALKER
# C : 2021/04/09
# M : 2021/04/09
# D : Wait until a song is over and update stats.

source client.sh
source player.sh
source statistics.sh

declare _ID

stalk() {
  # wait until a song is over.
  # 

  __is_mpd_running || return 1

  local s
  s="$(state -p)"

  [[ $s == "pause" || $s == "stop" ]] && return 1

  local duration elapsed song
  # shellcheck disable=2119
  {
    duration="$(getduration)"
    elapsed="$(getelapsed)"
  }

  song="$(getcurrent "%artist%: %title%")"

  # cmd albumart "$(getcurrent)" 0 > "$img"
  notify-send -i "$(get_albumart)" "$(status)"

  _ID="$(getcurrent "%id%")"

  sleep $((duration-elapsed))

  echo "played: ${song,,}"
}

stalk & pid=$!
  
while read -r; do
  sleep 0.125

  s="$(state -p)"

  # song changed.
  if [[ $(getcurrent "%id%") != "$_ID" ]] && \
    kill -0 "$pid" 2> /dev/null; then
      [[ $s == "play" ]] && {
        kill "$pid" 2> /dev/null
        stalk & pid=$!
        continue
      }
  fi
  
  # pause/stop.
  [[ $s == "pause" || $s == "stop" ]] && {
    kill "$pid" 2> /dev/null
    unset pid
    continue
  }
  
  # song ended normally.
  if [[ $s == "play" ]] && ! kill -0 "$pid" 2> /dev/null; then
    stalk & pid=$!
  fi

done < <(./idlecmd loop player)
