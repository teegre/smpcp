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
# PLAYER
# C │ 2021/04/02
# M │ 2021/04/10
# D │ Player functions.

toggle() {
  # toggle music player playback state.
  # if a track number is given, play it.

  if [[ "${*}" ]]; then
    play "$@"
  elif ! state; then
    play
  else
    cmd pause
  fi
}

play() {
  # start playback.

  local track
  track="$1"

  if [[ $track ]]; then
    cmd play $((track-1))
  else
    cmd play
  fi
}

stop() {
  # stop playback.

  state && cmd stop
}

stop_after_current() {
  # stop playback when current song is over.

  state || return 1

  [[ $(read_config single) == "on" ]] && {
    single 0 &> /dev/null || return 1
    write_config single off || return 1
    __msg M "stop after current: off."
    return 0
  }

  single 1 &> /dev/null || return 1
  write_config single on || return 1
  __msg M "stop after current: on."
}

next() {
  # play next song.
  cmd next
}

previous() {
  # play previous song.
  cmd previous
}

seek() {
  # seek within current song.
  # usage: seek [+-]<[[HH:]MM:]SS> or [+-]<0-100%>
  # + seek forward from current song position.
  # - seek backward from current song position.
  # otherwise seek is performed from the start.

  state || {
    __msg E "not playing."
    return 1
  }

  local pos sign rel sk
  pos="$1"

  if [[ $pos =~ ^\+.*$ ]]; then
    ((rel=1))
    sign="+"
  elif [[ $pos =~ ^-.*$ ]]; then
    ((rel=-1))
  else
    ((rel=0))
  fi

  # % seek.
  if [[ $pos =~ ^[+\|-]?([0-9]+)%$ ]]; then
    local p
    p="${BASH_REMATCH[1]}"

    ((p < 0 || p > 100)) && {
      __msg E "invalid number."
      return 1
    }

    local cpos
    cpos="$(getduration)"

    ((sk=p*cpos/100))

  # [[HH:]MM:]SS seek.
  elif [[ $pos =~ ^[+\|-]?(.+)$ ]]; then

    local p T h m s
    p="${BASH_REMATCH[1]}"

    IFS=$'\n' read -d "" -ra T <<< "${p//:/$'\n'}"

    # SS
    if [[ ${#T[@]} -eq 1 ]]; then
      if [[ ${T[0]} =~ ^[0-9]+$ ]]; then
        s="${T[0]}"
        h=0
        m=0
      else
        __msg E "invalid number for secs."
        return 1
      fi
    # MM:SS
    elif [[ ${#T[@]} -eq 2 ]]; then
      # M
      if [[ ${T[0]} =~ ^[0-9]+$ ]]; then
        m="${T[0]}"
      else
        __msg E "invalid number for minutes."
        return 1
      fi
      # S
      if [[ ${T[1]} =~ ^[0-9]+$ ]]; then
        s="${T[1]}"
      else
        __msg E "invalid number for seconds."
        return 1
      fi
      h=0
    # HH:MM:SS
    elif [[ ${#T[@]} -eq 3 ]]; then
      # HH
      if [[ ${T[0]} =~ ^[0-9]+$ ]]; then
        h="${T[0]}"
      else
        __msg E "invalid number for hours."
        return 1
      fi
      # MM
      if [[ ${T[1]} =~ ^[0-9]+$ ]]; then
        m="${T[1]}"
      else
        __msg E "invalid number for minutes."
        return 1
      fi
      # SS
      if [[ ${T[2]} =~ ^[0-9]+$ ]]; then
        s="${T[2]}"
      else
        __msg E "invalid number for seconds."
        return 1
      fi
    fi
    ((sk=(h*3600)+(m*60)+s))
  fi

  [[ $rel -eq -1 ]] && ((sk=-sk))

  if [[ $rel ]]; then
    cmd seekcur "${sign}${sk}"
  else
    cmd seekcur "$sk"
  fi
}

__playback_mode() {
  # playback mode:
  # enable/disable/show status.
  # enable with on or 1.
  # disable with off or 0.
  # print status otherwise.

  local mode value
  mode="$1"; shift
  value="$(fcmd status "$mode")"

  [[ -z $value ]] && return 1

  if [[ -z $1 ]]; then
    case $value in
      0) __msg M "${mode}: off" ;;
      1) __msg M "${mode}: on"
    esac
  elif [[ $1 == "on" || $1 == "1" ]]; then
    case $value in
      0) cmd "$mode" 1 && __msg M "${mode}: on" ;;
      1) __msg M "${mode}: on"
    esac
  elif [[ $1 == "off" || $1 == "0" ]]; then
    case $value in
      0) __msg M "${mode}: off" ;;
      1) cmd "$mode" 0 && __msg M "${mode}: off"
    esac
  fi
}

# repeat()  { __playback_mode repeat  "$1"; }
random()  { __playback_mode random  "$1"; }
single()  { __playback_mode single  "$1"; }
consume() { __playback_mode consume "$1"; }

xfade() {
  # crossfade:
  # set/show status.

  if [[ $1 =~ ^[0-9]+ ]]; then
    cmd crossfade "$1" || return 1
    __msg M "xfade $1 second(s)"
  elif [[ -z $1 ]]; then
    local value
    value="$(fcmd status xfade)"
    case $value in
      "") __msg M "xfade off" ;;
      * ) __msg M "xfade $value"
    esac
  else
    __msg E "invalid value."
    return 1
  fi
}

replaygain() {
  # replaygain:
  # set/show status.

  case $1 in
    track) cmd replay_gain_mode track || return 1 ;;
    album) cmd replay_gain_mode album || return 1 ;;
    auto ) cmd replay_gain_mode auto  || return 1 ;;
    *    ) __msg E "invalid parameter."; return 1
  esac

  __msg M "replay gain mode: $(fcmd replay_gain_status replay_gain_mode)"
}

pstatus() {
  # terse status display.

  local status state
  state="$(state -p)"

  case $state in
    play ) status="" ;;
    pause) status="" ;;
    stop ) status=""
  esac

  local options mode

  local -A __m
  __m["repeat"]="r"
  __m["random"]="z"
  __m["single"]="s"
  __m["consume"]="c"

  status+=" "

  options=( "repeat" "random" "single" "consume" )

  for mode in "${options[@]}"; do
    [[ "$(fcmd status "$mode")" -eq 1 ]] \
      && status+="${__m["$mode"]}" \
      || status+="-"
  done

  [[ $(fcmd status xfade) -gt 0 ]] \
    && status+="x" \
    || status+="-"

  echo "$status"
}

status() {
  # display player status
  # and current song info.

  echo "$(pstatus) $(rating) x$(playcount) [$(get_ext "$(getcurrent)")]"
  getcurrent "%artist%: %title%\n%album% | %date%"
}

