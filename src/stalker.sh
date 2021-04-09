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
source core.sh
source player.sh
source statistics.sh

declare _ID

__is_mpd_running || {
  __msg E "MPD is not running."
  exit 1
}

stalk() {
  # wait until a song is over.
  # 

  local s
  s="$(state -p)"

  [[ $s == "pause" || $s == "stop" ]] && return 1

  local duration elapsed song
  # shellcheck disable=2119
  {
    duration="$(getduration)"
    elapsed="$(getelapsed)"
  }

  song="$(getcurrent)"

  notify-send -i "$(get_albumart)" "$(status)"
  media_update

  _ID="$(getcurrent "%id%")"

  sleep $((duration-elapsed))

  update_stats "$song" && echo "$(now) --- $song"
}


__stalking() { kill -0 "$pid" 2> /dev/null && return 0 || return 1; }

stalk & pid=$!
__stalking || unset pid
  
while read -r; do
  sleep 1

  s="$(state -p)"

  # song changed.
  [[ $(getcurrent "%id%") != "$_ID" ]] && __stalking && {
    [[ $s == "play" ]] && {
      kill "$pid" 2> /dev/null
      stalk & pid=$!
      continue
    }
  }
  
  # pause/stop.
  [[ $s == "pause" || $s == "stop" ]] && {
    kill "$pid" 2> /dev/null
    unset pid
    media_update
    continue
  }
  
  # song ended normally.
  [[ $s == "play" ]] && ! __stalking && {
    stalk & pid=$!
  }

done < <(./idlecmd loop player)
