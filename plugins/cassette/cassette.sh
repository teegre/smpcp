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
# CASSETTE PLUGIN
# C : 2021/06/04
# M : 2021/06/30
# D : Programmable audio recorder.

export PLUG_CASSETTE_VERSION="0.2"

plug_cassette() {
  local command
  command="$1"; shift

  case $command in
    start ) cassette_start  && return 0 || return 1 ;;
    stop  ) cassette_stop   && return 0 || return 1 ;;
    status) cassette_status && return 0 || return 1 ;;
    cancel) cassette_cancel && return 0 || return 1 ;;
    ""    ) cassette_status && return 0 || return 1 ;;
  esac

  [[ $command != "set" ]] && {
    message E "invalid command."
    return 1
  }

  local duration date url

  duration="$1"; shift
  date="$1"; shift
  url="$1"; shift

  [[ $duration =~ [0-9]+ ]] || {
    message E "invalid duration."
    return 1
  }

  date="$(date -d "$date" "+%s" 2> /dev/null)" || {
    message E "invalid date."
    return 1
  }

  ((date+(duration*60) <= EPOCHSECONDS)) && {
    message E "invalid date: $(_date "%F %H:%M" "$date")"
    return 1
  }

  [[ $url ]] || {
    message E "no url."
    return 1
  }

  local pid
  pid="$(read_config cassette_pid)" && {
    message W "a recording is already scheduled - removing."
    kill "$pid" 2> /dev/null
  }
  write_config cassette_duration $((duration*60))
  write_config cassette_date "$date"
  write_config cassette_url "${url%#*}" 2> /dev/null

  cassette_schedule & disown
  write_config cassette_pid $!
}

help_cassette() {
  echo "args=[start|stop|set|cancel];desc=audio recorder."
}

__plug_cassette_notify() {
  case $1 in
    stop | pause )
      [[ $(get_output_state recorder) == "0" ]] && return
      logme "cassette: stopped."
      cassette_stop &> /dev/null
    ;;
    start )
      local pid
      pid="$(read_config cassette_pid)" || return
      (( pid == 0 )) && {
        cassette_schedule & disown
        write_config cassette_pid $!
        logme "cassette: restart scheduled recording."
      }
    ;;
    quit )
      local pid
      logme "cassette: quit."
      pid="$(read_config cassette_pid)" || return
      (( pid != 0 )) && write_config cassette_pid 0
    ;;
  esac
}

cassette_status() {
  [[ $(get_output_state recorder) == "1" ]] && {
    local filename
    filename="$(read_config cassette_filename)" || unset filename
    [[ $filename ]] && {
      local duration _time
      duration="$(read_config cassette_duration)" || unset duration
      _time="$(read_config cassette_date)" || unset _time
      message M "cassette: recording ${filename}."
      [[ $duration ]] && message M "$(secs_to_hms $((_time+duration-EPOCHSECONDS))) left."
    }
    return 0
  }

  local duration date
  duration="$(read_config cassette_duration)" || unset duration
  date="$(read_config cassette_date)"
  [[ $duration ]] && {
    message M "a $((duration/60)) minute(s) cassette is scheduled for recording."
    message M "recording will start on $(LC_TIME=C _date "%A" "$date") at $(_date "%H:%M" "$date")."
    message M "url: $(read_config cassette_url)"
    return 0
  }

  message M "no cassette."
  return 1
}

cassette_start() {
  [[ $(get_output_state recorder) == "1" ]] && return 1
  local filename
  filename="cassette_$(_date "%Y%m%d%H%M%S").ogg"
  write_config cassette_filename "$filename"
  set_output recorder on &> /dev/null
  [[ $(state -p) != "play" ]] && play
}

cassette_stop() {
  [[ $(get_output_state recorder) == "0" ]] && return 1
  [[ $1 == "--no-kill" ]] && {
    local NOKILL=1
    shift
  }
  [[ $NOKILL ]] || {
    pid="$(read_config cassette_pid)" || unset pid
    [[ $pid ]] && kill "$pid" 2> /dev/null
  }
  local dir filename musicdir
  dir="${SMPCP_PLUGINS_DIR}/cassette"
  filename="$(read_config cassette_filename)"
  musicdir="$(get_music_dir)" || unset musicdir
  stop
  set_output recorder off &> /dev/null
  [[ $musicdir ]] && {
    [[ -d ${musicdir}/cassette ]] || mkdir "${musicdir}/cassette"
    mv "${dir}/cassette.ogg" "${musicdir}/cassette/${filename}"
    echo "cassette/${filename}" >> ~/.config/mpd/playlists/recordings.m3u
    cmd update "cassette"
    message M "cassette: saved cassette/${filename}"
  }
  [[ $musicdir ]] || {
    mv "${dir}/cassette.ogg"  "${dir}/${filename}"
    message M "cassette: saved ${dir}/${filename}"
  }
  cassette_clear
}

cassette_clear() {
  remove_config cassette_duration
  remove_config cassette_date
  remove_config cassette_url
  remove_config cassette_pid
  remove_config cassette_filename
}

cassette_schedule() {
  local _time duration url
  _time="$(read_config cassette_date)" || return 1
  duration="$(read_config cassette_duration)"
  url="$(read_config cassette_url)"

  (( _time-EPOCHSECONDS < 0 )) && {
    logme "cassette: cancel scheduled recording."
    cassette_clear
    return 1
  }

  sleep $((_time-EPOCHSECONDS)) 2>/dev/null

  # start recording
  save_state
  stop
  cmd clear
  add "$url"

  cassette_start
  logme "cassette: recording..."

  sleep $((_time+duration-EPOCHSECONDS))

  logme "cassette: stop recording."

  cassette_stop --no-kill &> /dev/null

  logme "cassette: end."

  cmd clear

  restore_state &> /dev/null
}

cassette_cancel() {
  local pid
  pid="$(read_config cassette_pid)" || unset pid
  [[ $pid ]] && {
    [[ $(get_output_state recorder) == "on" ]] && {
      message W "stopping current recording."
      cassette_stop --no-kill
    }
    kill "$pid" 2> /dev/null && {
      message M "cassette: recording cancelled."
      logme "cassette: cancelled."
      cassette_clear
      return 0
    }
  }
  message E "no scheduled recording."
}
