# shellcheck shell=bash

#
# .▄▄ · • ▌ ▄ ·.  ▄▄▄· ▄▄·  ▄▄▄· super
# ▐█ ▀. ·██ ▐███▪▐█ ▄█▐█ ▌▪▐█ ▄█ music
# ▄▀▀▀█▄▐█ ▌▐▌▐█· ██▀·██ ▄▄ ██▀· player
# ▐█▄▪▐███ ██▌▐█▌▐█▪·•▐███▌▐█▪·• client
#  ▀▀▀▀ ▀▀  █▪▀▀▀.▀   ·▀▀▀ .▀    plus+
#
# This file is a part of smpcp.
# Copyright (C) 2021-2023, Stéphane MEYER.
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
# NOTIFY
# C : 2021/05/20
# M : 2023/12/26
# D : Notification helper functions.

notify_song() {
  # display notification for the given URI
  # or the current song.
  # usage: notify_song [uri]

  which notify-send 2>&1 > /dev/null ||
    return 1

  local uri

  if [[ $1 ]]; then
    uri="$1"
    shift
  else
    uri="$(get_current)"
  fi

  notify-send -i "$(get_albumart "$uri")" "$(status "$uri")"
}

notify_player() {
  
  which notify-send 2>&1 > /dev/null ||
    return 1

  if [[ $1 ]]; then
    local msg
    msg="$1"
    shift
  fi

  notify-send -i "$SMPCP_ICON" -t 2000 "$(pstatus)" "$msg"
}
