# shellcheck shell=bash

#
# .▄▄ · • ▌ ▄ ·.  ▄▄▄· ▄▄·  ▄▄▄· super
# ▐█ ▀. ·██ ▐███▪▐█ ▄█▐█ ▌▪▐█ ▄█ music
# ▄▀▀▀█▄▐█ ▌▐▌▐█· ██▀·██ ▄▄ ██▀· player
# ▐█▄▪▐███ ██▌▐█▌▐█▪·•▐███▌▐█▪·• client
#  ▀▀▀▀ ▀▀  █▪▀▀▀.▀   ·▀▀▀ .▀    plus+
#
# This file is a smpcp plugin.
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
# VOICEOVER
# C : 2021/05/20
# M : 2021/05/20
# D : Random track artist/title or current time voiceover.

export PLUG_VOICEOVER_VERSION="0.1"

__plug_voiceover_notify() {
  [[ $1 == "change" ]] && {
    local minutes
    minutes="$(_date "%M")"
    if ((minutes%15==0)); then
      if voiceover time; then
        write_config voiceover off
      elif [[ $(get_mode) == "1" ]] && random &> /dev/null; then
        write_config voiceover on
      fi
    else
      ((RANDOM%10==5)) && {
        if voiceover; then
          write_config voiceover off
        elif [[ $(get_mode) == "1" ]] && random &> /dev/null; then
          write_config voiceover on
        fi
      }
    fi
  }
}

voiceover() {

  type espeak &> /dev/null || return 1

  [[ $(read_config voiceover) == "off" ]] && return 1
  [[ $(state -p) != "play" ]] && return 1
  [[ $(get_mode) != "1" ]] && return 1
  random &> /dev/null || return 1
  [[ $(read_config dim) == "on" ]] && return 1

  local uri
  uri="$(get_current)"

  [[ $uri == *[![:ascii:]]* ]] && return 1

  local dur
  dur="$(get_duration)"

  ((dur<120)) && return 1

  local radio
  radio="$(read_config radio_station_name)" ||
    radio="music non stop radio"

  local msg
  if [[ $1 == "time" ]]; then
    msg="... It is now: $(LC_TIME=C _date "%l %M %p")... On ${radio}."
  else
    msg="... You are listening to: $(get_current '[[%artist%...]]%title%')... On ${radio}."
  fi

  local gender voice wav cvol vol
  wav="/tmp/voiceover.wav"
  
  ((gender=RANDOM%2))
  ((gender==0)) && gender="f" || gender="m"

  voice="${gender}$((RANDOM%3+2))"
  
  espeak -v en+${voice} -w "${wav}" -s 140 &> /dev/null <<< "$msg"
  
  ((cvol=$(fcmd status volume)))
  ((vol=cvol-cvol*30/100))

  volume $((vol)) &> /dev/null
  
  paplay --volume $((65536*cvol/100)) "$wav"

  volume $((cvol)) &> /dev/null

  rm "$wav"

  return 0
}
