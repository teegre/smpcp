#! /usr/bin/env bash

#
# .▄▄ · • ▌ ▄ ·.  ▄▄▄· ▄▄·  ▄▄▄· super
# ▐█ ▀. ·██ ▐███▪▐█ ▄█▐█ ▌▪▐█ ▄█ music
# ▄▀▀▀█▄▐█ ▌▐▌▐█· ██▀·██ ▄▄ ██▀· player
# ▐█▄▪▐███ ██▌▐█▌▐█▪·•▐███▌▐█▪·• client
#  ▀▀▀▀ ▀▀  █▪▀▀▀.▀   ·▀▀▀ .▀    plus+
#
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
# SMPCP
# C │ 2021/04/04
# M │ 2021/05/16
# D │ Main program.

declare SMPCP_LIB="/usr/lib/smpcp"

# shellcheck source=/usr/lib/smpcp/client.sh
source "$SMPCP_LIB"/client.sh
# shellcheck source=/usr/lib/smpcp/core.sh
source "$SMPCP_LIB"/core.sh
# shellcheck source=/usr/lib/smpcp/help.sh
source "$SMPCP_LIB"/help.sh
# shellcheck source=/usr/lib/smpcp/player.sh
source "$SMPCP_LIB"/player.sh
# shellcheck source=/usr/lib/smpcp/playlist.sh
source "$SMPCP_LIB"/playlist.sh
# shellcheck source=/usr/lib/smpcp/plugin.sh
source "$SMPCP_LIB"/plugin.sh
# shellcheck source=/usr/lib/smpcp/query.sh
source "$SMPCP_LIB"/query.sh
# shellcheck source=/usr/lib/smpcp/statistics.sh
source "$SMPCP_LIB"/statistics.sh
# shellcheck source=/usr/lib/smpcp/tracker.sh
source "$SMPCP_LIB"/tracker.sh
# shellcheck source=/usr/lib/smpcp/volume.sh
source "$SMPCP_LIB"/volume.sh

__is_mpd_running || {
  message E "MPD is not running."
  exit 1
}

try_plugin() {
  if plugin_function_exists "$1"; then
    plugin_function_exec "$@"
  else
    message E "invalid command: ${1}."
    return 1
  fi
}

case $1 in
  add        ) shift; add "$@" ;;
  addalbum   ) shift; add_album "$@" ;;
  albuminfo  ) get_album_info ;;
  albums     ) shift; get_discography "$@" ;;
  clear      ) clear_queue ;;
  consume    ) shift; consume "$@" ;;
  crop       ) crop ;;
  DEBUG      ) shift; "$@" ;;
  delete     ) shift; delete "$@" ;;
  dim        ) shift; dim "$@" ;;
  getcurrent ) shift; get_current "$@" ;;
  getduration) shift; get_duration "$@" ;;
  getelapsed ) shift; get_elapsed "$@" ;;
  getnext    ) shift; get_next "$@" ;;
  getprev    ) shift; get_previous "$@" ;;
  getrnd     ) shift; get_rnd "$@" ;;
  help       ) _help ;;
  history    ) _db_get_history ;;
  insertalbum) shift; add_album -i "$@" ;;
  load       ) shift; load "$@" ;;
  ls         ) shift; list_queue "$@" ;;
  mode       ) shift; _mode "$@" ;;
  move       ) shift; move "$@" ;;
  next       ) next ;;
  nextalbum  ) next_album ;;
  pause      ) pause ;;
  play       ) shift; play "$@" ;;
  playalbum  ) shift; add_album -p "$@" ;;
  playtime   ) db_playtime ;;
  pls        ) shift; list_playlist "$@" ;;
  plugins    ) shift; list_plugins ;;
  prev       ) previous ;;
  random     ) shift; random "$@";;
  rating     ) shift; rating "$@" ;;
  repeat     ) shift; _repeat "$@" ;;
  replaygain ) shift; replaygain "$@" ;;
  search     ) shift; search "$@" ;;
  searchadd  ) shift; searchadd "$@" ;;
  seek       ) shift; seek "$@" ;;
  songinfo   ) song_stats ;;
  single     ) shift; single "$@" ;;
  skip       ) shift; skip ;;
  status     ) status ;;
  stop       ) stop ;;
  toggle     ) shift; toggle "$@" ;;
  tracker    ) tracker ;;
  update     ) shift; update "$@" ;;
  version    ) message M "smpcp: version ${__version}." ;;
  vol        ) shift; volume "$@" ;;
  xfade      ) shift; xfade "$@" ;;
  ""         ) _print_version; status ;;
  *          ) try_plugin "$@"
esac
