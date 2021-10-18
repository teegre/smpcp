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
# PLUGIN EXAMPLE
# C : 2021/10/18
# M : 2021/10/18
# D : Save current playback position and stop.

# version
export PLUG_BOOKMARK_VERSION=0.1

__bookmark_id() {
  state && {
    local musicdir song
    musicdir="$(get_music_dir)" || return 1
    song="$(get_current)"
    printf "%x" "$(stat -c "%i" "${musicdir}/${song}")" &&
      return 0
  }
  return 1
}

help_bookmark() {
  echo "args=; desc=save current playback position and stop."
}

plug_bookmark() {
  state && {
    id="$(__bookmark_id)" || return 1
    write_config "bookmark_${id}" "$(get_elapsed)" && {
      message M "saved bookmark ${id}."
      stop
      return 0
    }
    return 1
  }
  message M "nothing to do."
  return 1
}

__plug_bookmark_notify() {
  case $1 in
    play)
      local id pos
      id="$(__bookmark_id)"
      pos="$(read_config "bookmark_${id}")" || return
      logme "bookmark: restore bookmark ${id}."
      seek $((pos))
      remove_config "bookmark_${id}" &&
        logme "bookmark: removed bookmark ${id}."
  esac
}
