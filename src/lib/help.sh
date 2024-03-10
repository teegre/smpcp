# shellcheck shell=bash

#
# .▄▄ · • ▌ ▄ ·.  ▄▄▄· ▄▄·  ▄▄▄· super
# ▐█ ▀. ·██ ▐███▪▐█ ▄█▐█ ▌▪▐█ ▄█ music
# ▄▀▀▀█▄▐█ ▌▐▌▐█· ██▀·██ ▄▄ ██▀· player
# ▐█▄▪▐███ ██▌▐█▌▐█▪·•▐███▌▐█▪·• client
#  ▀▀▀▀ ▀▀  █▪▀▀▀.▀   ·▀▀▀ .▀    plus+
#
# This file is part of smpcp.
# Copyright (C) 2021-2024, Stéphane MEYER.
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
# M : 2024/03/10
# D : Help.

_help() {
cat << EOB
smpcp: version ${__version}

Commands:
  smpcp add <uri>                                  add song(s) to the queue.
  smpcp addalbum [<artist> <album>]                append album to the queue.
  smpcp addsong  <artist> <title>                  append song to the queue.
  smpcp albuminfo                                  display current album full info.
  smpcp albums                                     display albums in the database for current artist.
  smpcp cdadd [<track>|<start-end>...]             add audio cd tracks to the queue.
  smpcp cdplay                                     play an audio cd.
  smpcp clear                                      remove all songs from the queue.
  smpcp cload <name> [<pos>|<start-end>...]        clear queue and load a stored playlist (see 'load').
  smpcp consume [off|on]                           set consume mode.
  smpcp crop                                       remove all songs from the queue except the current one.
  smpcp dbplaytime                                 display database playtime.
  smpcp delete <position>|<start-end>              delete song(s) from the queue.
  smpcp dim [-n]                                   toggle volume dim.
  smpcp getcurrent [format]                        show info about current song.
  smpcp getduration [-h]                           display duration of current song.
  smpcp getelapsed [-h]                            display elapsed time for current song.
  smpcp getnext [format]                           show info about next song in the queue.
  smpcp getprev [format]                           show info about previously played song.
  smpcp getrnd [-a] <count>                        print <count> random songs or albums (-a).
  smpcp help                                       show this help screen.
  smpcp history                                    show playback history.
  smpcp insertalbum [<artist> <album>]             add album after current song.
  smpcp load <name> [[pos]|[start-end]...]         load playlist or specific songs into the queue.
  smpcp ls [-f [format]]                           print queue.
  smpcp lsalbums [artist]                          print albums.
  smpcp lsartists                                  print artists.
  smpcp lsdir [uri]                                print (sub)directory/file list.
  smpcp lsoutputs                                  print available outputs.
  smpcp mode [song|album|off]                      set mode or print status.
  smpcp move [<position> | <start-end>] <to>       move song(s) within the queue.
  smpcp next                                       play next song in the queue.
  smpcp nextalbum                                  play another random album (album mode only).
  smpcp npls <name>                                display numbered content of a stored playlist.
  smpcp oneshot [on|off]                           set oneshot mode.
  smpcp output <name> <on|off>                     enable/disable an output.
  smpcp pause                                      pause playback.
  smpcp play [pos]                                 play song.
  smpcp playalbum [<artist> <album>]               play album for current song.
  smpcp playtime                                   display user playtime.
  smpcp pls [name]                                 list stored playlists or content of a given playlist.
  smpcp plugins                                    list installed plugins.
  smpcp prev                                       play song from the start or play previous song.
  smpcp random [off|on]                            set random mode.
  smpcp rating [0..5]                              rate current song.
  smpcp remove <name>                              delete given stored playlist.
  smpcp repeat [off|on]                            set repeat mode.
  smpcp replaygain [auto|track|album]              set replay gain mode.
  smpcp save <name>                                save current queue to playlist.
  smpcp search <type> <query>                      search for songs.
  smpcp searchadd <type> <query>                   search for songs and add them to queue.
  smpcp seek [+|-]<[HH:[MM:]]SS> | [+|-]<0-100%>   seek to specified position.
  smpcp single [off|on]                            set single mode.
  smpcp songinfo                                   print info about current song.
  smpcp skip                                       skip current track.
  smpcp state [-p]                                 playback state (-p to print).
  smpcp status                                     print player status.
  smpcp stop                                       stop playback.
  smpcp toggle [pos]                               toggle play/pause.
  smpcp tracker                                    idle mode, print music player events.
  smpcp unskip                                     reset current song skip count.
  smpcp update [uri]                               update database.
  smpcp version                                    show program version and exit.
  smpcp vol [-n] [+|-]<vol>                        set volume.
  smpcp xfade [duration]                           set crossfade duration.
$(plugin_help)
EOB
}

_print_version() {
  echo "smpcp version $__version"
  echo "This program is free software."
  echo -e "It is distributed AS IS with NO WARRANTY.\n"
}
