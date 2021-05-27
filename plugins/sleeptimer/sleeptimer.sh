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
# SLEEPTIMER
# C : 2021/04/26
# M : 2021/05/27
# D : Pause playback after time out.

export PLUG_SLEEPTIMER_VERSION="0.1"
SLEEPTIMER_PID="$SMPCP_PLUGINS_DIR/sleeptimer/pid"

help_sleeptimer() {
  echo "args=[0|off|1-120] [-t]; desc=pause playback after time out."
}

__plug_sleeptimer_notify() {
 
  local dur
  dur="$(read_config sleeptimer_duration)" || return
  ((dur==0)) && return
 
  if [[ $1 == "stop" ]] || [[ $1 == "pause" ]] || [[ $1 == "quit" ]]; then
    plug_sleeptimer off
    logme "sleeptimer: turned off."
  fi
}

sleeptimer() {

  local expire elapsed dur
  expire="$(read_config sleeptimer_expiration)"

  while ((EPOCHSECONDS<expire)); do

    sleep 60

    ((EPOCHSECONDS>=expire)) && {
      if [[ $(get_current) =~ ^https? ]]; then
        stop
      else
        pause
      fi
      write_config sleeptimer_duration 0
      write_config sleeptimer_expiration 0
      rm "$SLEEPTIMER_PID"
      logme "sleeptimer: end."
      return
    }

    dur="$(get_next "%time%")" || continue
    elapsed="$(get_elapsed)"

    ((EPOCHSECONDS+(dur-elapsed)>=expire)) && {
      plugin_function_exec stopafter stopafter on &> /dev/null ||
        continue
      logme "sleeptimer: $(secs_to_hms $((dur-elapsed))) left."
      write_config sleeptimer_duration 0
      write_config sleeptimer_expiration 0
      rm "$SLEEPTIMER_PID"
      return
    }
  done
}

kill_sleeptimer() {

  [[ -a $SLEEPTIMER_PID ]] && { 
    local pid
    pid="$(<"$SLEEPTIMER_PID")"
    check_pid "$pid" && {
      kill "$pid" 2> /dev/null
      rm "$SLEEPTIMER_PID"
    }
  }
}

plug_sleeptimer() {
  # pause playback after time out.
  # usage: sleeptimer
  # usage: sleeptimer <0|off|1-120>
  # usage: sleeptimer -t
  # without option, display status.
  # options:
  #  -t  through 30 60 90 120 off

  [[ $(state -p) != "play" ]] && {
    message E "not playing."
    return 1
  }

  # if single mode is enabled, there is
  # no need for a sleep timer.
  single &> /dev/null && {
    local duration elapsed expire
    duration="$(get_duration)"
    elapsed="$(get_elapsed)"
    expire="$(secs_to_hms $((duration-elapsed)))"

    message M "sleeptimer: ${expire} left."
    return
  }

  if [[ $1 ]]; then 
    # toggle
    if [[ $1 == "-t" ]]; then
      shift
      local dur
      dur="$(read_config sleeptimer_duration)" || dur=0

      ((dur=dur%2!=0?30:dur<30?30:dur+30))
      ((dur>120)) && dur=0

    # manual
    else
      local dur="$1"
      [[ $dur == "off" ]] && dur=0

      [[ $dur =~ [0-9]+ ]] || {
        message E "invalid duration."
        return 1
      }
    fi

    ((dur==0)) && {
      kill_sleeptimer
      write_config sleeptimer_duration 0
      write_config sleeptimer_expiration 0
      message M "sleep timer: off."
      logme "sleeptimer: turned off."
      return 0
    }

    ((dur<1 || dur>120)) && {
      message E "invalid duration."
      return 1
    }

    write_config sleeptimer_duration $((dur))
    write_config sleeptimer_expiration $((EPOCHSECONDS+(dur*60)))
    kill_sleeptimer
    sleeptimer & echo $! > "$SLEEPTIMER_PID"
    message M "sleep timer: $dur minutes."
    logme "sleeptimer: started --> $(_date "%T" $((EPOCHSECONDS+(dur*60))))"
    return 0
  fi

  # show status
  local dur
  dur="$(read_config sleeptimer_expiration)" || dur=0
  
  ((dur==0)) && {
    message M "sleep timer: off."
    return 0
  }

  ((dur-=EPOCHSECONDS))

  message M "sleep timer: $(secs_to_hms $((dur))) left."
  return 0
}
