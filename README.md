```
.▄▄ · • ▌ ▄ ·.  ▄▄▄· ▄▄·  ▄▄▄· super
▐█ ▀. ·██ ▐███▪▐█ ▄█▐█ ▌▪▐█ ▄█ music
▄▀▀▀█▄▐█ ▌▐▌▐█· ██▀·██ ▄▄ ██▀· player
▐█▄▪▐███ ██▌▐█▌▐█▪·•▐███▌▐█▪·• client
 ▀▀▀▀ ▀▀  █▪▀▀▀.▀   ·▀▀▀ .▀    plus+
```

# SMPCP

## Description

**Smpcp** is a client for [Music Player Daemon](https://www.musicpd.org) written in Bash (and a little C), that includes some more advanced features like:

*  Auto-generated playlists.
*  Song rating.
*  Playback statistics.
*  Can be extended with plugins.

**/!\ This is work in progress.**

## Dependencies

Latest version of these packages are needed:

bash
coreutils
gnu-netcat
imagemagick
libmpdclient
mpd
sqlite3
util-linux

## Install

Clone this repository: `git clone https://gitlab.com/teegre/smpcp.git`

Then: `cd smpcp`

Finally: `make install`

## Uninstall

`make uninstall`

## Configuration

**smpcp** reads its configuration from `$XDG_CONFIG_HOME/smpcp`.  
You need to make a copy of the configuration file called **settings** that can be found in `/etc/smpcp` directory:

`mkdir $HOME/.config/smpcp`

`cp /etc/smpcp/settings ~/.config/smpcp`

Below are the settings that have to be modified:

`music_library`: path to the music directory (tilde is expanded).

`sticker_db`: path to the sticker database.

`keep_in_history = 2 weeks`: how long a song is kept in history. (If a song is in history it won't be added to the queue when an auto-playlist is generated.)

`skip_limit = 2`: how many times a song can be skipped before being ignored in auto-playlists.

## Usage

```
  smpcp add <uri>                                  add song(s) to the queue.
  smpcp addalbum [<artist> <album>]                append album to the queue.
  smpcp albuminfo                                  display current album full info.
  smpcp albums                                     display albums in the database for current artist.
  smpcp clear                                      remove all songs from the queue.
  smpcp cload <name> [[pos]|[start-end]...]        clear queue and load a stored playlist (see 'load').
  smpcp consume [off|on]                           set consume mode.
  smpcp crop                                       remove all songs from the queue except the current one.
  smpcp dbplaytime                                 display database playtime.
  smpcp delete <position> | <start-end>            delete song(s) from the queue.
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
  smpcp mode [song|album|off]                      set mode or print status.
  smpcp move [<position> | <start-end>] <to>       move song(s) within the queue.
  smpcp next                                       play next song in the queue.
  smpcp nextalbum                                  play another random album (album mode only).
  smpcp pause                                      pause playback.
  smpcp play [pos]                                 play song.
  smpcp playalbum [<artist> <album>]               play album for current song.
  smpcp playtime                                   display user playtime.
  smpcp pls [name]                                 list stored playlists or content of a given playlist.
  smpcp plugins                                    list installed plugins.
  smpcp prev                                       play song from the start or play previous song.
  smpcp random [off|on]                            set random mode.
  smpcp rating [0..5]                              rate current song.
  smpcp repeat [off|on]                            set repeat mode.
  smpcp replaygain [auto|track|album]              set replay gain mode.
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
  smpcp update [uri]                               update database.
  smpcp version                                    show program version and exit.
  smpcp vol [-n] [+|-]<vol>                        set volume.
  smpcp xfade [duration]                           set crossfade duration.
  smpcp goodbye [name]                             say goodbye to someone or to the whole world.
  smpcp hello [name]                               either greets someone or the whole world.
  smpcp sleeptimer [0|off|1-120] [-t]              pause playback after time out.
  smpcp stopafter [-n] [on|off]                    stop playback after current song.
```

## Daemon

To enable auto-playlists and playback statistics, **smpcpd** - the **smpcp** daemon - must be running. A systemd unit is provided for this purpose.

To enable the daemon:

`systemctl user enable smpcpd`

To start the daemon:

`systemctl user start smpcpd`.

