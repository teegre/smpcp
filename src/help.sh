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
# HELP
# C : 2021/04/13
# M : 2021/04/18
# D : Help.

_help() {
cat << EOB
smpcp: version ${__version}

Commands:
  smpcp add <uri>                                  add song(s) to the queue.
  smpcp addalbum [<artist> <album>]                append album to the queue.
  smpcp albuminfo                                  display current album full info.
  smpcp clear                                      remove all songs from the queue.
  smpcp cmd [-x] <command> [args]                  -
  smpcp consume [off|on]                           set consume mode.
  smpcp crop                                       remove all songs from the queue except current one.
  smpcp delete <position> | <start-end>            delete song(s) from the queue.
  smpcp dim                                        toggle volume dim.
  smpcp discog                                     display albums in the database from current artist.
  smpcp getcurrent [format]                        show info about current song.
  smpcp getduration [-h]                           display duration of current song.
  smpcp getelapsed [-h]                            display elapsed time for current song.
  smpcp getnext [format]                           show info about next song in the queue.
  smpcp getrnd [-a] <count>                        print <count> random songs or albums (-a).
  smpcp getsticker <uri> <name>                    print sticker.
  smpcp help                                       show this help screen.
  smpcp history                                    show song history.
  smpcp idle [event...]                            -
  smpcp idleloop [event...]                        -
  smpcp insertalbum [<artist> <album>]             add album after current song.
  smpcp fcmd [-x] <command> [args] <filter>        -
  smpcp ls                                         print queue.
  smpcp mode [song|album|off]                      set mode or print status.
  smpcp move [<position> | <start-end>] <to>       move song(s) within the queue.
  smpcp next                                       play next song in the queue.
  smpcp nextalbum                                  play another random album (album mode only).
  smpcp pause                                      pause playback.
  smpcp play [pos]                                 play song.
  smpcp playalbum [<artist> <album>]               play album for current song.
  smpcp prev                                       play song from the start or play previous song.
  smpcp random [off|on]                            set repeat mode.
  smpcp rating [0..5]                              rate song.
  smpcp repeat [off|on]                            set repeat mode.
  smpcp replaygain [mode]                          set replay gain mode.
  smpcp search <type> <query>                      search for songs.
  smpcp searchadd <type> <query>                   search for songs and add them to queue.
  smpcp seek [+|-]<[HH:[MM:]]SS> | [+|-]<0-100%>   seek to specified position.
  smpcp single [off|on]                            set single mode.
  smpcp skip                                       skip current track.
  smpcp status                                     print player status
  smpcp stop                                       stop playback.
  smpcp stop_after                                 stop playback after current song.
  smpcp toggle [pos]                               toggle play/pause. play if paused.
  smpcp update [uri]                               update database.
  smpcp vol [+|-]<vol>                             set volume.
  smpcp xfade [duration]                           set crossfade duration.
EOB
}

_print_version() {
  echo "smpcp version $__version"
  echo "This program is free software."
  echo -e "It is distributed AS IS with NO WARRANTY.\n"
}
