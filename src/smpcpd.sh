#! /usr/bin/env bash

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
# SMPCPD
# C : 2021/04/10
# M : 2021/10/20
# D : Music non stop daemon.

declare SMPCP_LIB="/usr/lib/smpcp"

# shellcheck source=/usr/lib/smpcp/client.sh
source "$SMPCP_LIB"/client.sh
# shellcheck source=/usr/lib/smpcp/core.sh
source "$SMPCP_LIB"/core.sh
# shellcheck source=/usr/lib/smpcp/notify.sh
source "$SMPCP_LIB"/notify.sh
# shellcheck source=/usr/lib/smpcp/player.sh
source "$SMPCP_LIB"/player.sh
# shellcheck source=/usr/lib/smpcp/playlist.sh
source "$SMPCP_LIB"/playlist.sh
# shellcheck source=/usr/lib/smpcp/plugin.sh
source "$SMPCP_LIB"/plugin.sh
# shellcheck source=/usr/lib/smpcp/query.sh
source "$SMPCP_LIB"/query.sh
# shellcheck source=/usr/lib/smpcp/tracker.sh
source "$SMPCP_LIB"/tracker.sh
# shellcheck source=/usr/lib/smpcp/statistics.sh
source "$SMPCP_LIB"/statistics.sh
# shellcheck source=/usr/lib/smpcp/volume.sh
source "$SMPCP_LIB"/volume.sh

declare URI

# check if an instance is already running.
_daemon && {
  message E "an instance is already running."
  exit 1
}

# save current pid.
echo "$$" > "$SMPCPD_PID"

logme --clear

logme "daemon: started."

echo "daemon started."

clear_media

while ! __is_mpd_running; do
  sleep 1
done

restore_state

plugin_notify "start"

add_songs() {
  # add songs to the queue.

  get_mode &> /dev/null || return 1

  # sometimes in random mode there's not next song
  # even if the queue contains more than one track.
  # disabling and re-enabling random mode fix the issue.
  get_next &> /dev/null || {
    [[ $(queue_length) -gt 1 ]] && {
      random 0
      random 1
      get_next &> /dev/null && return 1
    }
  }

  [[ $(queue_length) -gt 1 ]] && return 1

  logme "daemon: add songs."

  local mode
  mode="$(get_mode)"

  if [[ $mode -eq 1 ]]; then
    local songcount
    songcount="$(read_config playlist_song_count)" || songcount=10
    plugin_notify "add" 2> /dev/null
    touch "$SMPCPD_LOCK"
    notify_player "Now adding songs..."
    get_rnd $((songcount)) | add
    plugin_notify "added"
    __song_mode
    rm "$SMPCPD_LOCK"
    state || play
    return 0
  elif [[ $mode -eq 2 ]]; then
    plugin_notify "add" 2> /dev/null
    touch "$SMPCPD_LOCK"
    notify_player "Now adding album..."
    get_rnd -a 1 | add
    plugin_notify "added"
    __album_mode
    rm "$SMPCPD_LOCK"
    state || play
    return 0
  fi

  return 1
}

play_event() {
  while [[ -a $SMPCPD_LOCK ]]; do sleep 1; done
  URI="$(get_current)"
  volume auto
  media_update
  notify_song "$(get_current)"

  # handle playlist generator here vvv
  add_songs

  logme "daemon: play."
}

pause_event() {
  notify_song "$(get_current)"

  media_update

  logme "daemon: pause."
}

stop_event() {
  media_update
  get_mode &> /dev/null || notify_player "stopped."

  logme "daemon: stop."
}

change_event() {
  while [[ -a $SMPCPD_LOCK ]]; do sleep 1; done
  URI="$(get_current)"

  notify_song "$URI"

  media_update

  # handle playlist generator here vvv
  add_songs
}

end_event() {
  while [[ -a $SMPCPD_LOCK ]]; do sleep 1; done
  update_stats "$URI" ||
    logme "daemon: [ERROR] could not update song statistics. uri: $URI"
  add_songs && {
    state || play
  }
}

update_daemon() {
  add_songs
}

quit_daemon() {
  logme "daemon: shutting down."
  echo "shutting down..."
  plugin_notify "quit"
  clear_media
  save_state
  :> "$SMPCPD_PID"
  RUN=0
  logme "daemon: quit."
}

loop() {
  logme "daemon: listening to events."
  local event
  while read -r event; do
    # react to player events
    # play
    # pause
    # stop
    # change
    # end

    plugin_notify "$event" 2> /dev/null

    case $event in
      play  ) play_event ;;
      pause ) pause_event ;;
      stop  ) stop_event ;;
      change) change_event ;;
      end   ) end_event
    esac

  done < <(tracker)
}

# use this trap to add new songs to the queue.
trap update_daemon HUP

trap quit_daemon INT QUIT TERM

echo "reading database..."
update_song_list && {
  echo "done."
  echo "cleaning orphan stickers..."
  clean_orphan_stickers -q
}
echo "done."

# have to handle the case mpd is not running
# or was stopped when smpcpd was running...
RUN=1
while ((RUN)); do
  __is_mpd_running && {
    [[ $DETECT ]] && {
      unset DETECT
      logme "daemon: unpaused."
    }
    loop
  }
  [[ $RUN ]] && {
    [[ $DETECT ]] || { DETECT=1; logme "daemon: paused"; }
    sleep 1
  }
done

logme "daemon: stopped."
