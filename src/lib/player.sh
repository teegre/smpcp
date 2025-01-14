# shellcheck shell=bash

#
# .▄▄ · • ▌ ▄ ·.  ▄▄▄· ▄▄·  ▄▄▄· super
# ▐█ ▀. ·██ ▐███▪▐█ ▄█▐█ ▌▪▐█ ▄█ music
# ▄▀▀▀█▄▐█ ▌▐▌▐█· ██▀·██ ▄▄ ██▀· player
# ▐█▄▪▐███ ██▌▐█▌▐█▪·•▐███▌▐█▪·• client
#  ▀▀▀▀ ▀▀  █▪▀▀▀.▀   ·▀▀▀ .▀    plus+
#
# This file is part of smpcp.
# Copyright (C) 2021-2025, Stéphane MEYER.
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
# M │ 2023/12/27
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
  # usage: play [pos]

  state || is_daemon && get_mode &> /dev/null && queue_is_empty && {
    # too bad! playback is stopped, daemon is active, song/album mode
    # is enabled and queue is empty!
    # so we need to tell smpcpd to add songs for us 
    # by sending a HUP signal.
    update_daemon
    return
  }

  local track
  track="$1"

  if [[ $track ]]; then
    cmd play $((track-1))
  else
    cmd play
  fi
}

pause() {
  cmd pause
}

stop() {
  # stop playback.
  state && cmd stop
}

next() {
  # play next song.
  while [[ -a $SMPCPD_LOCK ]]; do sleep 1; done
  get_next &> /dev/null || return 1
  update_stats --no-playcount "$(get_current)"
  cmd next
}

next_album() {
  # play another album.

  local mode
  mode="$(get_mode)"
  [[ $mode -eq 2 ]] && is_daemon && {
    cmd clear
    update_daemon
    return 0
  }

  is_daemon || {
    message E "daemon is not running."
    return 1
  }

  [[ $mode -ne 2 ]] && {
    message E "not in album mode." 
    return 1
  }
}

previous() {
  # go back to the beginning of the current song
  # if 10% mark has been passed, or play previous song.

  state || {
    message E "not playing."
    return 1
  }

  # check 10% mark
  local dur elapsed percent
  dur="$(get_duration)"
  [[ $dur ]] && {
    elapsed="$(get_elapsed)"
    ((percent=elapsed*100/dur))
    ((percent>10)) && {
      cmd previous
      return
    }
  }

  # get previous song.
  local uri id
  uri="$(get_previous)"

  [[ $uri ]] || {
    message E "no previous song."
    return 1
  }

  if is_in_queue "$uri"; then
    cmd previous
  else
    local index id
    index="$(read_config history_index)" || index=0

    # shellcheck disable=SC2119
    random &> /dev/null || {
      local pos=0
    }

    id="$(fcmd addid "$uri" "$pos" Id)" || return 1

    write_config history_index $((++index))

    [[ $pos ]] || {
      local cid
      cid="$(get_current "%id%")"
      cmd playid $((id)) || return 1
      cmd prioid $((index)) $((cid))
      return 0
    }

    cmd previous
  fi
}

skip() {
  # skip current song.

  state || return 1

  local uri skipcount

  uri="$(get_current)"

  [[ $uri =~ ^cdda: ]] && return 1
  [[ $uri =~ ^https?: ]] && return 1

  while [[ -a $SMPCPD_LOCK ]]; do sleep 1; done

  skipcount="$(get_sticker "$uri" skipcount 2> /dev/null)" || skipcount=0
  ((skipcount++))
  update_stats "$uri"
  set_sticker "$uri" skipcount $((skipcount)) || return 1
  next
  return 0
}

unskip() {
  # reset skip count of the current song.

  state || return 1

  local uri

  uri="$(get_current)"

  [[ $uri =~ ^cdda: ]] && return 1
  [[ $uri =~ ^https?: ]] && return 1

  while [[ -a $SMPCPD_LOCK ]]; do sleep 1; done

  set_sticker "$uri" skipcount 0 || return 1

  return 0
}

seek() {
  # seek within current song.
  # usage: seek [+-]<[[HH:]MM:]SS> or [+-]<0-100%>
  # + seek forward from current song position.
  # - seek backward from current song position.
  # otherwise seek is performed from the start.

  state || {
    message E "not playing."
    return 1
  }

  (( $# == 0 )) && {
    if [[ $(get_current) =~ ^https? ]]; then
      message M "$(get_elapsed)"
    else
      message M "$(get_elapsed -h)/$(get_duration -h)"
    fi
    return 1
  }

  [[ $(get_current) =~ ^https? ]] && return 1

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
      message E "invalid number."
      return 1
    }

    local cpos
    cpos="$(get_duration)"

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
        message E "invalid number for secs."
        return 1
      fi
    # MM:SS
    elif [[ ${#T[@]} -eq 2 ]]; then
      # M
      if [[ ${T[0]} =~ ^[0-9]+$ ]]; then
        m="${T[0]}"
      else
        message E "invalid number for minutes."
        return 1
      fi
      # S
      if [[ ${T[1]} =~ ^[0-9]+$ ]]; then
        s="${T[1]}"
      else
        message E "invalid number for seconds."
        return 1
      fi
      h=0
    # HH:MM:SS
    elif [[ ${#T[@]} -eq 3 ]]; then
      # HH
      if [[ ${T[0]} =~ ^[0-9]+$ ]]; then
        h="${T[0]}"
      else
        message E "invalid number for hours."
        return 1
      fi
      # MM
      if [[ ${T[1]} =~ ^[0-9]+$ ]]; then
        m="${T[1]}"
      else
        message E "invalid number for minutes."
        return 1
      fi
      # SS
      if [[ ${T[2]} =~ ^[0-9]+$ ]]; then
        s="${T[2]}"
      else
        message E "invalid number for seconds."
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

_playback_mode() {
  # playback mode:
  # enable/disable/show state.
  # enable with on or 1.
  # disable with off or 0.
  # exit status:
  # 0 success
  # 1 fail
  # state + exit status:
  # 0 on
  # 1 off

  local mode value
  mode="$1"; shift
  [[ $1 == "-n" ]] && { local NOTIFY=1; shift; }
  value="$(fcmd status "$mode")"
  new_value="$1"; shift

  [[ -z $value ]] && return 1

  # show playback mode current state
  if [[ -z $new_value ]]; then
    case $value in
      0)
        [[ $NOTIFY ]] && notify_player "${mode}: off"
        [[ $NOTIFY ]] || message M "${mode}: off"
        return 1
        ;;
      1)
        [[ $NOTIFY ]] && notify_player "${mode}: on"
        [[ $NOTIFY ]] || message M "${mode}: on"
        return 0
        ;;
    esac
  # turn on
  elif [[ $new_value == "on" || $new_value == "1" ]]; then
    case $value in
      0)
        cmd "$mode" 1 && {
          [[ $NOTIFY ]] && notify_player "${mode}: on"
          [[ $NOTIFY ]] || message M "${mode}: on"
          return 0
        }
        return 1
        ;;
      1)
        [[ $NOTIFY ]] && notify_player "${mode}: on"
        [[ $NOTIFY ]] || message M "${mode}: on"
        return 0
        ;;
    esac
  # turn off
  elif [[ $new_value == "off" || $new_value == "0" ]]; then
    case $value in
      0)
        [[ $NOTIFY ]] && notify_player "${mode}: off"
        [[ $NOTIFY ]] && message M "${mode}: off"; return 0 ;;
      1)
        cmd "$mode" 0 && {
          [[ $NOTIFY ]] && notify_player "${mode}: off"
          [[ $NOTIFY ]] || message M "${mode}: off"
          return 0
        }
        return 1
        ;;
    esac
  fi
}

_repeat() { _playback_mode repeat  "$@"; }
# shellcheck disable=SC2120
random()  { _playback_mode random  "$@"; }
single()  { _playback_mode single  "$@"; }
consume() { _playback_mode consume "$@"; }

oneshot() {
  local value new_value
  [[ $1 == '-n' ]] && { local NOTIFY=1; shift; }
  value="$(fcmd status single)"
  new_value="$1"
  if [[ -z $new_value ]]; then
    [[ $value == "oneshot" ]] && { message M "oneshot: on";  return 0; }
    [[ $value == "oneshot" ]] || { message M "oneshot: off"; return 1; }
  else
    case $new_value in
      on )
        cmd single oneshot
        [[ $NOTIFY ]] && notify_player "oneshot: on"
        [[ $NOTIFY ]] || message M "oneshot: on"
        return 0
        ;;
      off)
        cmd single 0
        [[ $NOTIFY ]] && notify_player "oneshot: off"
        [[ $NOTIFY ]] || message M "oneshot: off"
        return 1
    esac
  fi
}

xfade() {
  # crossfade:
  # set/show status.
  # exit status
  # 0 on
  # 1 off

  if [[ $1 =~ ^[0-9]+ ]]; then
    cmd crossfade "$1" || return 1
    message M "xfade $1 second(s)"
  elif [[ -z $1 ]]; then
    local value
    value="$(fcmd status xfade)"
    case $value in
      "") message M "xfade off"; return 1 ;;
      * ) message M "xfade $value"; return 0
    esac
  else
    message E "invalid value."
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
    off  ) cmd replay_gain_mode off   || return 1 ;;
    ""   ) : ;;
    *    ) message E "invalid parameter."; return 1
  esac

  message M "replay gain mode: $(fcmd replay_gain_status replay_gain_mode)"
}

_mode() {
  # set play mode or print status.

  is_daemon || {
    message W "mode: off (daemon not running.)"
    write_config mode off
    return 1
  }

  case $1 in
    song  ) write_config mode song;  message M "mode: song"  ;;
    album ) write_config mode album; message M "mode: album" ;;
    norm  ) write_config mode off;   message M "mode: normal"; __normal_mode ;;
    normal) write_config mode off;   message M "mode: normal"; __normal_mode ;;
    off   ) write_config mode off;   message M "mode: normal"; __normal_mode ;;
    ""    ) message M "mode: $(read_config mode)" ;;
    *     ) message E "invalid option."
  esac
}

get_mode() {
  # helper function to get mode as an integer.
  # 0 normal/off
  # 1 song
  # 2 album

  local mode
  mode="$(read_config mode)" || mode="off"

  case $mode in
    off  ) echo 0; return 1 ;;
    song ) echo 1; return 0 ;;
    album) echo 2; return 0 ;;
    *    ) echo 0; return 1 ;; # just in case.
  esac
}

pstatus() {
  # terse status display.

  local status state
  state="$(state -p)"

  case $state in
    play ) status="$(read_config play_icon)"  || status="[>" ;;
    pause) status="$(read_config pause_icon)" || status="||" ;;
    stop ) status="$(read_config stop_icon)"  || status="[]"
  esac

  local options pbmode mode

  mode="$(read_config mode)" || mode="off"

  case $mode in
    off  ) mode="norm" ;;
    song ) mode="song" ;;
    album) mode="album" ;;
    *    ) mode="norm" ;;
  esac

  status+=" [${mode}] "

  local -A __m
  __m["repeat"]="r"
  __m["random"]="z"
  __m["single"]="s"
  __m["consume"]="c"

  options=( "repeat" "random" "single" "consume" )

  local pbmode_status
  for pbmode in "${options[@]}"; do
    pbmode_status="$(fcmd status "$pbmode")"
    if [[ $pbmode_status -eq 1 ]]; then
      status+="${__m["$pbmode"]}"
    elif [[ $pbmode_status == "oneshot" ]]; then
      status+="1"
    else
      status+="-"
    fi
  done

  [[ $(fcmd status xfade) -gt 0 ]] \
    && status+="x" \
    || status+="-"

  [[ $(read_config dim) == "on" ]] \
    && status+="d" \
    || status+="-"

  echo "$status"
}

status() {
  # display player status
  # and current song info.

  local uri

  if [[ $1 ]]; then
    uri="$1"
    shift
  else
    uri="$(get_current)"
  fi

  local fmt
  fmt="$(read_config status_format)" || 
    fmt="[[%artist% - ]]%title%"

  # stream?
  if [[ $uri =~ ^https?: ]]; then
    pstatus
    printf "%s\n" "$(get_current "%name%\n${fmt}")"
  else
    echo "$(pstatus) $(rating "$uri") x$(playcount "$uri")"
    local info
    info="$(get_current "$fmt")"
    [[ $info ]] || echo "$uri"
    [[ $info ]] && echo "$info"
  fi
}

