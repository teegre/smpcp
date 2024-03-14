# shellcheck shell=bash

#
# .▄▄ · • ▌ ▄ ·.  ▄▄▄· ▄▄·  ▄▄▄· super
# ▐█ ▀. ·██ ▐███▪▐█ ▄█▐█ ▌▪▐█ ▄█ music
# ▄▀▀▀█▄▐█ ▌▐▌▐█· ██▀·██ ▄▄ ██▀· player
# ▐█▄▪▐███ ██▌▐█▌▐█▪·•▐███▌▐█▪·• client
#  ▀▀▀▀ ▀▀  █▪▀▀▀.▀   ·▀▀▀ .▀    plus+
#
# This file is a smpcp plugin.
# Copyright (C) 2024, Stéphane MEYER.
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
# ALARM PLUGIN
# C : 2024/03/03
# M : 2024/03/14
# D : Wake up with music.

export PLUG_ALARM_VERSION="0.1"

plug_alarm() {
  command="$1"; shift

  case $command in
    status) alarm_status; return $? ;;
    cancel) alarm_cancel; return $? ;;
    ""    ) alarm_status; return $? ;;
  esac

  [[ $command != "set" ]] && {
    message E "invalid command."
    return 1
  }

  local dt ct url

  dt="$1"; shift
  url="$1"; shift

  dt="$(date -d "$dt" "+%s" 2> /dev/null)" || {
    message E "invalid date."
    return 1
  }
  
  ((ct=EPOCHSECONDS))
  ((dt <= ct)) && {
    message E "invalid date."
  }

  local pid
  pid="$(read_config alarm_pid)" && {
    message W "an alarm is already scheduled - removing."
    kill "$pid" 2> /dev/null
  }

  write_config alarm_date "$dt"
  [[ $url ]] && write_config alarm_url "${url%#*}" 2> /dev/null

  alarm_schedule & disown
  write_config alarm_pid $!
}

help_alarm() {
  echo "args=[set|status|cancel] [url];desc=wake up with music."
}

__plug_alarm_notify() {
  case $1 in
    start )
      local pid
      pid="$(read_config alarm_pid)" || return
      (( pid == 0 )) && {
        alarm_schedule & disown
        write_config alarm_pid $!
        logme "alarm: re-scheduled."
      }
    ;;
    quit )
      local pid
      logme "alarm: quit."
      pid="$(read_config alarm_pid)" || return
      (( pid != 0 )) && write_config alarm_pid 0
    ;;
  esac
}

alarm_status() {
  local dt
  dt="$(read_config alarm_date)" || unset dt

  [[ $dt ]]&& {
    message M "alarm will start on $(LC_TIME=C _date "%A" "$dt") at $(_date "%H:%M" "$dt")."
    url="$(read_config alarm_url)" && message M "url: $url"
    return 0
  }

  message M "no alarm."
  return 1
}

alarm_stop() {
  [[ $1 == "--no-kill" ]] && {
    local NOKILL=1
    shift
  }
  [[ $NOKILL ]] || {
    pid="$(read_config alarm_pid)" || unset pid
    [[ $pid ]] && kill "$pid" 2> /dev/null
  }
  alarm_clear
}

alarm_clear() {
  remove_config alarm_date
  remove_config alarm_url
  remove_config alarm_pid
}

alarm_schedule() {
  local _time url
  _time="$(read_config alarm_date)" || return 1
  url="$(read_config alarm_url)" || unset url

  (( _time-EPOCHSECONDS < 0 )) && {
    logme "alarm: cancelled."
    alarm_clear
    return 1
  }

  sleep $((_time-EPOCHSECONDS)) 2>/dev/null

  # add url
  [[ $url ]] && {
    cmd clear
    add "$url"
  }

  [[ $url ]] || {
    queue_is_empty && [[ $(get_mode) == 0 ]] && {
      # We want to make sure music will be playing!
      _mode song &> /dev/null
      [[ $(get_mode) == 0 ]] && {
        # Add some music forcibly
        get_rnd | add
        __song_mode
      }
    }
  }

  play
  alarm_stop --no-kill

  logme "alarm: on."
}

alarm_cancel() {
  local pid
  pid="$(read_config alarm_pid)" || unset pid
  [[ $pid ]] && alarm_stop --no-kill
  kill "$pid" 2> /dev/null && {
    message M "alarm: cancelled."
    logme "alarm: cancelled."
    alarm_clear
    return 0
  }
  
  message E "no alarm."
}
