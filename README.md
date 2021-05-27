```
.▄▄ · • ▌ ▄ ·.  ▄▄▄· ▄▄·  ▄▄▄· super
▐█ ▀. ·██ ▐███▪▐█ ▄█▐█ ▌▪▐█ ▄█ music
▄▀▀▀█▄▐█ ▌▐▌▐█· ██▀·██ ▄▄ ██▀· player
▐█▄▪▐███ ██▌▐█▌▐█▪·•▐███▌▐█▪·• client
 ▀▀▀▀ ▀▀  █▪▀▀▀.▀   ·▀▀▀ .▀    plus+
```

# SMPCP

## Description

**Smpcp** is a command line client for [Music Player Daemon](https://www.musicpd.org) written in Bash (and a little C), that includes some more advanced features like:

*  Auto-generated playlists (song and album modes).
*  Notifications (with album art).
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
libnotify  
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

### Mandatory settings

Tilde in filesystem path is expanded.

`music_library`: path to the music directory. (i.e. `~/music`)

`sticker_db`: path to the sticker database. (i.e `~/.config/mpd/sticker.sql`)

### Optional settings

`playlist_song_count`: how many songs have to be added when an auto-playlist is generated (defaults to 10).

`keep_in_history = 2 weeks`: how long a song is kept in history.  
(If a song is in history it won't be added to the queue when an auto-playlist is generated.)

`skip_limit = 3`: how many times a song can be skipped before being ignored in auto-playlists.

`resume_state = off`: save/restore queue and playback state on startup/shutdown.

Indicator for playback state shown in status/notification.
`play_icon`  (default [|>)  
`pause_icon` (default [||)  
`stop_icon`  (default [|])

`status_format` (default is `[[%artist% - ]]%title%`)  
To learn more about formatting, see below: Output formatting.

## Daemon

To enable auto-playlists and playback statistics, **smpcpd** - the **smpcp** daemon - must be running. A systemd unit is provided for this purpose.

To enable the daemon:

`systemctl --user enable smpcpd`

To start the daemon:

`systemctl --user start smpcpd`.

## Quick start

Here we assume **smpcpd** is up and running with default settings.

To execute a command: `smpcp <command> [options]`

### Status

The `status` command:

```
playback state
|
| mode
| |      playback options
| |      |
| |      |      song rating
| |      |      |
| |      |      |     song playcount
| |      |      |     |
| |      |      |     |   file format
| |      |      |     |   |
v v      v      v     v   v
▶️ [song] -z-cx- ***** x13 [mp3]
Beastie Boys
Sabotage
Ill Communication | 1994
```
### Playback options status and associated commands

It is displayed as one character:

*  r - repeat    | command: `repeat [on|off]`
*  z - random    | command: `random [on|off]`
*  s - single    | command: `single [on|off]`
*  c - consume   | command: `consume [on|off]`
*  x - crossfade | command: `xfade [duration_in_seconds]`
*  d - dim       | command: `dim [-n]` (-n option to display a notification)

### Playback control

*  `play [pos]`
*  `pause`
*  `toggle [pos]`
*  `next`
*  `skip` - increments the current song's skipcount and play the next song in the queue.
*  `prev`
*  `seek [+|-]<[[HH:]MM:]SS>|[+|-]<0-100%>`
*  `playalbum [<artist> <album>]` - plays given album or play the current song's album.
*  `insertalbum [<artist> <album>]` - add given album or current song's album after the current song.

### Volume control

*  `vol [-n] [+|-][0-100]` - change volume.
*  `dim [-n]: -6dB volume dim.

### Queue management

* ls add del move crop clear

### Song mode

In song mode, **smpcpd** adds 10 random songs to the current queue and sets the following playback options: random, consume and 10 seconds crossfade. When there's only one song left in the queue, **smpcpd** adds 10 other songs.

To enable song mode: `smpcp mode song`.

### Album mode

In album mode, a random album is added to the current queue and consume is enabled. **smpcpd** adds another album when the last song starts.

The *nextalbum* command starts playback of a new album.

To enable album mode: `smpcp mode album`.

### Normal mode

In normal mode, songs have to be added manually.

To enable normal mode: `smpcp mode normal` or `smpcp mode off`.

### Stored playlists

* load cload save remove

### Info and statistics

It is possible to rate the songs with the *rating* command. In song mode, songs rated 4 or 5 are more likely to be picked when generating a playlist.

The *songinfo* and *albuminfo* command prints information about the current song/album:

```
> smpcp songinfo
Speedy J: Hayfever
Public Energy No.1 (1997)
00:37 / 05:36
====
rating:      ****-
last played: 2021-03-13 19:53:59
play count:  7
skip count:  0

> smpcp albuminfo
01. │ 02:42 │ Tuning In
02. │ 08:34 │ Patterns
03. │ 02:38 │ Melanor
04. │ 08:10 │ In-Formation
05. │ 05:21 │ Pure Energy
06. │ 04:34 │ Haywire
07. │ 05:36 │ Hayfever
08. │ 02:21 │ Tesla
09. │ 07:48 │ Drainpipe
10. │ 08:40 │ Canola
11. │ 09:04 │ As The Bubble Expands
---
Speedy J: Public Energy No.1 (1997)
11 tracks - 01:05:28
```

The *albums* command prints a list of albums in the music database for the current artist:

```
> smpcp albums
A Shocking Hobby (2000)
Public Energy No.1 (1997)
---
Speedy J - 2 albums / 22 songs.
Total playtime: 02:01:35
```

## Output formatting

Some commands (ie `ls` with -f option) can use a format to display songs.

Available tags are

Tag | Description
:---|:-----------
%file% | path of file relative to music directory
%ext%  | lowercase file extension
%last-modified | file modification date
%artist% | artist name
%albumartist% | artist of album; if not found, falls back to %artist%
%name% | internet radio's name
%album% | album's title
%title% | song's title
%track% | track number
%disc%  | disc number
%genre% | genre
%date%  | date
%time%  | song duration in seconds (integer)
%duration% | song duration in seconds (floating point)
%pos% | song position in the queue
%id%  | unique song id in the queue

If no format is given when a command expects one, it defaults to %file%.

If a tag is empty or missing, it is stripped from the source string. 
A substring surrounded by double square brackets is also stripped if it contains an empty or missing tag.  
For example, `Now playing\n[[artist: %artist%\n]]title: %title%`, assuming %artist% tag is not found, would output:

```
Now playing
title: song title
```

## Available commands

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
  smpcp remove <name>                              remove given stored playlist.
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
```

