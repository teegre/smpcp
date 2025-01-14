#! /usr/bin/env bash

#
# .▄▄ · • ▌ ▄ ·.  ▄▄▄· ▄▄·  ▄▄▄· super
# ▐█ ▀. ·██ ▐███▪▐█ ▄█▐█ ▌▪▐█ ▄█ music
# ▄▀▀▀█▄▐█ ▌▐▌▐█· ██▀·██ ▄▄ ██▀· player
# ▐█▄▪▐███ ██▌▐█▌▐█▪·•▐███▌▐█▪·• client
#  ▀▀▀▀ ▀▀  █▪▀▀▀.▀   ·▀▀▀ .▀    plus+
#
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
# SMPCP
# C │ 2021/04/04
# M │ 2025/01/14
# D │ Main program.

declare SMPCP_LIB="${HOME}/.local/lib/smpcp"

source "$SMPCP_LIB"/client.sh
source "$SMPCP_LIB"/core.sh
source "$SMPCP_LIB"/help.sh
source "$SMPCP_LIB"/notify.sh
source "$SMPCP_LIB"/player.sh
source "$SMPCP_LIB"/playlist.sh
source "$SMPCP_LIB"/plugin.sh
source "$SMPCP_LIB"/query.sh
source "$SMPCP_LIB"/statistics.sh
source "$SMPCP_LIB"/tracker.sh
source "$SMPCP_LIB"/volume.sh


[[ -a $SMPCP_SETTINGS ]] || {
  message E "missing configuration file."
  message M "see smpcp.conf(5) for more info."
  exit 1
}

is_mpd || {
  message E "MPD is not running."
  exit 1
}

try_plugin() {
  if plugin_function_exists "$1"; then
    plugin_function_exec "$@"
  else
    message E "invalid command: ${1}"
    return 1
  fi
}

exec_command() {
  case $1 in
    add        ) shift; add "$@" ;;
    addalbum   ) shift; add_album "$@" ;;
    addsong    ) shift; add_song "$@" ;;
    albuminfo  ) get_album_info ;;
    albums     ) shift; get_discography "$@" ;;
    cdadd      ) shift; cdadd "$@" ;;
    cdplay     ) shift; cdadd -p "$@" ;;
    clear      ) clear_queue ;;
    cload      ) shift; cload "$@" ;;
    consume    ) shift; consume "$@" ;;
    crop       ) crop ;;
    dbg        ) shift; "$@" ;;
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
    lsalbums   ) shift; list_albums "$@" ;;
    lsartists  ) shift; list_artists "$@" ;;
    lsdir      ) shift; list_dir "$@" ;;
    lsoutputs  ) shift; list_outputs "$@" ;;
    mode       ) shift; _mode "$@" ;;
    move       ) shift; move "$@" ;;
    next       ) next ;;
    nextalbum  ) next_album ;;
    npls       ) shift; list_numbered_playlist_content "$@" ;;
    output     ) shift; set_output "$@" ;;
    oneshot    ) shift; oneshot "$@" ;;
    pause      ) pause ;;
    play       ) shift; play "$@" ;;
    playalbum  ) shift; add_album -p "$@" ;;
    pls        ) shift; list_playlist "$@" ;;
    plugins    ) shift; list_plugins ;;
    prev       ) previous ;;
    random     ) shift; random "$@";;
    rating     ) shift; rating "$@" ;;
    remove     ) shift; remove "$@" ;;
    repeat     ) shift; _repeat "$@" ;;
    replaygain ) shift; replaygain "$@" ;;
    save       ) shift; save "$@" ;;
    search     ) shift; search "$@" ;;
    searchadd  ) shift; searchadd "$@" ;;
    seek       ) shift; seek "$@" ;;
    songinfo   ) song_stats ;;
    single     ) shift; single "$@" ;;
    skip       ) shift; skip ;;
    state      ) shift; state "$@" ;;
    stats      ) shift; show_stats "$@" ;;
    status     ) shift; status "$@" ;;
    stop       ) stop ;;
    toggle     ) shift; toggle "$@" ;;
    tracker    ) tracker ;;
    unskip     ) unskip ;;
    update     ) shift; update "$@" ;;
    version    ) message M "smpcp: version ${__version}." ;;
    vol        ) shift; volume "$@" ;;
    xfade      ) shift; xfade "$@" ;;
    *          ) try_plugin "$@"
  esac
}

if ! [[ $1 ]]; then
  _print_version
  status
  exit 0
fi

for arg in "$@"; do
  [[ $arg == "++" ]] || IFS= arglist+=("$arg")
  [[ $arg == "++" ]] && {
    # shellcheck disable=SC2068
    set -- ${arglist[@]}
    IFS=' ' exec_command "$@"
    unset arglist
  }
done

[[ ${arglist[*]} ]] && { IFS=' ' exec_command "${arglist[@]}"; }
