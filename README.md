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

`skip_limit = 2`: how many times a song can be skipped before being ignored in auto-playlists.

## Daemon

To enable auto-playlists and playback statistics, **smpcpd** - the **smpcp** daemon - must be running. A systemd unit is provided for this purpose.

To enable the daemon:

`systemctl user enable smpcpd`

To start the daemon:

`systemctl user start smpcpd`.

## Quick start

Here we assume **smpcpd** is up and running with default settings.

To execute a command: `smpcp <command> [options]`

### Status

The *status* command:

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
### Playback options status

It is displayed as one character:

*  r - repeat
*  z - random
*  s - single
*  c - consume
*  x - crossfade
*  d - dim

### Playback control

*  play pause toggle next skip prev seek

*  playalbum: plays album for the currently playing song.

### Volume control

*  vol
*  dim: -6dB dimmer.

### Queue management

* ls add del move crop clear

### Song mode

In song mode, **smpcpd** adds 10 random songs to the current queue and sets the following playback options: random, consume and 10 seconds crossfade. When there's only one song left in the queue, **smpcpd** adds 10 other songs.

To enable song mode: `smpcp mode song`.

### Album mode

In album mode, a random album is added to the current queue. **smpcpd** adds another album when the last song starts.

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
Autechre: Foil
Amber (1994)
00:17 / 06:04
====
rating:      ****-
last played: 2021-04-03 08:25:16
play count:  11
skip count:  0
```

```
> smpcp albuminfo
01. │ 06:05 │ Foil
02. │ 07:16 │ Montreal
03. │ 05:31 │ Silverside
04. │ 06:21 │ Slip
05. │ 06:16 │ Glitch
06. │ 08:01 │ Piezo
07. │ 03:40 │ Nine
08. │ 10:07 │ Further
09. │ 06:37 │ Yulquen
10. │ 07:49 │ Nil
11. │ 06:46 │ Teartear
---
Autechre: Amber (1994)
11 tracks - 01:14:29
```

The *albums* command prints a list of albums in the music database for the current artist:

```
> smpcp albums
AE_LIVE_BRUSSELS_031014 (2014)
AE_LIVE_DOUR_180715 (2015)
AE_LIVE_DUBLIN_150718 (2020)
AE_LIVE_DUBLIN_191214 (2014)
AE_LIVE_GRAFENHAINICHEN_170715 (2015)
AE_LIVE_HELSINKI_141116 (2020)
AE_LIVE_KATOWICE_210815 (2015)
AE_LIVE_KRAKOW_200914 (2014)
AE_LIVE_KREMS_020515 (2015)
AE_LIVE_MELBOURNE_210618 (2020)
AE_LIVE_NAGANO_300515 (2015)
AE_LIVE_NIJMEGEN_221116 (2020)
AE_LIVE_OSLO_171116 (2020)
AE_LIVE_TALLINN_131116 (2020)
AE_LIVE_UTRECHT_221114 (2014)
AE_LIVE_ZAGREB_061116 (2020)
ATP 3.0 - Autechre Curated (2003)
Amber (1994)
Anti EP (1994)
Anvil Vapre (1995)
Basscad, Ep (1994)
Blech II:Blechsdöttir (1996)
Bleep:10 (2014)
Chiastic Slide (1997)
Cichlisuite (1997)
Confield (2001)
Dekmantel Podcast (2015)
Draft 7.30 (2003)
Envane (1997)
Ep7 (1999)
Exai (2013)
Gantz Graf (2002)
Garbage (1995)
Incunabula (1993)
L-event (2013)
Legacy of Dissolution (2005)
Lp5 (1998)
Move Of Ten (2010)
NTS Session 1 (2018)
NTS Session 2 (2018)
NTS Session 3 (2018)
NTS Session 4 (2018)
Odd Jobs (1999)
Oversteps (2010)
PLUS (2020)
Peel Session 08-09-99 (1999)
Peel Session 13-10-95 (1998)
Pi (1998)
Quaristice (2007)
Quaristice.Quadrange.ep.ae (2008)
SIGN (2020)
The Top 100 Tracks of 2010 (2010)
Tri Repetae (1995)
Untilted (2005)
Warp Tapes 89-93 (2019)
Warp20 [Chosen] (2009)
Warp20 [Recreated] (2008)
Warp20 [Unheard] (2009)
We Are Reasonable People (Wap100) (1998)
elseq 1 (2016)
elseq 2 (2016)
elseq 3 (2016)
elseq 4 (2016)
elseq 5 (2016)
sinistrail sentinel (2018)
---
Autechre - 65 albums / 313 songs.
Total playtime: 2 days, 14:17:24
```
Yeah, I like Autechre! 😂

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

