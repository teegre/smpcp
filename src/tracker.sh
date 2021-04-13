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
# TRACKER
# C : 2021/04/09
# M : 2021/04/12
# D : Player event tracker.

_wait() {
  # wait until the song is over.

  local STATE
  STATE="$(state -p)"

  [[ $STATE == "pause" || $STATE == "stop" ]] &&
    return 1

  local duration elapsed

  # shellcheck disable=2119
  {
    duration="$(getduration)"
    elapsed="$(getelapsed)"
  }

  sleep $((duration-elapsed))

  echo "end"
}


tracker() {
  # track and print player events.
  # events:
  #   change - next or previous song playback has started.
  #   end    - the song was played thoroughly.
  #   play   - player has been started or resumed.
  #            a play event is also printed if tracker is started
  #            while a song is playing.
  #   pause  - player has been paused.
  #   stop   - player has been stopped.

  local PID ID STATE

  _wait & PID=$!
  ID="$(getcurrent "%id%")"

  if wait_for_pid 1 "$PID"; then
    unset PID ID
  else
    echo "play"
  fi

  while read -r; do

    STATE="$(state -p)"

    # play
    [[ ! $ID ]] && [[ $STATE == "play" ]] && {
      
      echo "play"

      _wait & PID=$!
      ID="$(getcurrent "%id%")"
      continue
    }

    # song changed.
    if [[ $(getcurrent "%id%") != "$ID" ]]; then
      [[ $STATE == "play" ]] && {

        wait_for_pid 2 "$PID" || {

          echo "change"

          kill "$PID" 2> /dev/null
          _wait & PID=$!
          ID="$(getcurrent "%id%")"
          continue
        }
      }
    fi
    
    # pause/stop.
    [[ $STATE == "pause" || $STATE == "stop" ]] && {

      echo "$STATE"

      ! wait_for_pid 2 "$PID" && kill "$PID" 2> /dev/null
      unset PID ID
      continue
    }
    
    # seek/duplicate event.
    # sometimes mpd idle command generates duplicates messages,
    # even though it seems only one event occured, so we have to
    # replace actual _wait process just in case something really
    # happened.
    [[ $(getcurrent "%id%") == "$ID" ]] &&
      ! wait_for_pid 1 "$PID" && [[ $STATE == "play" ]] && {

        kill "$PID" 2> /dev/null
        _wait & PID=$!
        continue
    }

    wait $PID

    # song ended normally.
    [[ $STATE == "play" ]] && {

      _wait & PID=$!
      ID="$(getcurrent "%id%")"
      
      echo "change"
    }

  done < <(cmd idleloop player)
}
