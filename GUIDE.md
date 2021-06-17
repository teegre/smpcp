# PLUGINS DEVELOPER GUIDE

Plugins must be written in Bash.

## Plugins Location

Plugins must be installed in `$XDG_CONFIG_HOME/.config/smpcp/plugins` and must be stored in separate directories.

## Plugin functions

Name of exposed plugin functions must be prefixed with `plug_`.

If the plugin needs to receive player events, a function named `__plug_plugin-name_notify` must be created.

This function is called each time a player event occurs and event is passed as the first and only argument `$1`.

Player events are:

*  `play` - playback started
*  `pause` - playback paused
*  `stop` - playback stopped
*  `end` - reached the end of current song
*  `change` - a new song is playing
*  `add` - new songs are added
*  `quit` - daemon is quitting

## Plugin version

The global variable `$PLUG_PLUGIN-NAME_VERSION` is used to set plugin version.

## Plugin Help

The function "help_plugin-function" is used to print function's arguments and a short description, e.g.:

```bash
_help_myfunction() {
  echo "args=<arg1> [arg2];desc=function description."
}
```

## Example Plugin

You can check source code of a simple plugin at: `plugins/hello/hello.sh`

# API

This is a summary of available libraries/functions for developing a plugin.

Libraries are stored in `/usr/lib/smpcp`.

These libraries are sourced by default:

*  client.sh
*  core.sh
*  help.sh
*  player.sh
*  playlist.sh
*  plugin.sh
*  query.sh
*  statistics.sh
*  tracker.sh
*  volume.sh

# core.sh

**core.sh** contains general purpose utility functions.

## Environment variables:

`SMPCP_ASSETS` assets directory.  
`SMPCP_CACHE` cache directory (used for album art images).  
`SMPCP_LOG` log file.  
`SMPCP_SETTINGS` settings file.  
`SMPCP_ICON` default icon (for notifications).

## Functions:

### _date

Usage: `_date <format> [unix_timestamp]`

Prints actual date/time or unix timestamp in the given format.

### secs_to_hms

Usage: `secs_to_hms <duration_in_seconds>`

Convert a duration in seconds to `[[W week(s),] [D day(s),]] [HH:]MM:SS`

### now

Prints current date and time (`YYYY-MM-DD HH:MM:SS`).

### logme

Usage: `logme <message>`  
Usage: `logme --clear`

A simple logger.

Log file is stored in `$HOME/.config/smpcp/log`

`--clear` backup and clear log file.

`<message>` can contain new line character.

### get_ext

Usage: `get_ext <uri>`

Prints lower case file extension.

### _max

Usage: `_max <value1> <value2> ... <valueN>`  
Usage: `<command> | _max`

Prints max value.

### message

Usage: `message <E|M|W> <message>`

Prints a message on stdout or stderr.

`E` stands for ERROR.  
`M` stands for MESSAGE.  
`W` stands for WARNING.

### read_config

Usage: `read_config <parameter>`

Reads from settings file and prints value for the given parameter.

### write_config

Usage: `write_config <parameter> <value>`

Writes value for the given parameter in the settings file.  
Appends parameter to config file if not already present.

### remove_config

`Usage: remove_config <parameter>`

Removes a parameter from the settings file.

### check_pid

Usage: `check_pid <pid>`

Checks whether the given process is running or not.

Returns exit status 0 if true, 1 otherwise.

### wait_for_pid

Usage: `wait_for_pid <duration> <pid>`

Waits for process to terminate for a given duration in seconds.

Returns exit status 0 if process ended, 1 otherwise.

### _daemon

Checks whether **smpcpd** is running or not.

Returns exit status 0 if true, 1 otherwise.

### update_daemon

Sends HUP signal to **smpcpd** to notify it to add new songs to the queue.

# client.sh

**client.sh** is a basic MPD client.

## Functions :

### __is_mpd_running

Checks whether MPD is running or not.

Returns exit status 0 if true, 1 otherwise.

### cmd

Usage: `cmd [-x] <mpd_command> [options]`

Send a command to MPD.

Check MPD Protocol Documentation for the full list of commands:

[https://mpd.readthedocs.io/en/stable/protocol.html](https://mpd.readthedocs.io/en/stable/protocol.html)

`-x` sets netcat buffering output delay time to 1 second.  
It prevents netcat from prematurely returning while an expensive task is running (i.e listall).

### fcmd

Usage: `fcmd [-c] [-x] <mpd_command> [options] <key[+key2+...+keyN]>`

Filters command output by printing value for given keys.

`-c` prints line count only.

`-x` see `cmd`.

Example: printing the current song bitrate:

`fcmd status bitrate`

### state

Usage: `state [-p]`

Returns exit status 0 if playing or paused, 1 if stopped.

`-p` prints actual state. Can be *play*, *pause* or *stop*.

### _parse_song_info

`Usage: _parse_song_info [-s] [format]`

Parses song information in the given format.

This function is meant to be used with queue related commands such as *playlistinfo*.  
Use `-s` option when using with *lsinfo*, *search* or similar commands.

Examples:

`cmd lsinfo "kraftwerk/the_man_machine" | _parse_song_info -s "%track%. %title"`

```
1. The Robots
2. Spacelab
3. Metropolis
4. The Model
5. Neon Lights
6. The Man Machine
```
About formatting

Format string can be anything and '%' enclosed tags are expanded  by *_parse_song_info*

If a tag is empty or missing, it is stripped from the source string.  
A substring surrounded by double square brackets `[[tag: %tag%]]` is also stripped if it contains a missing or empty tag.

For instance:

`[[tag: %missing-tag% ]]title: %title%`

Since %missing-tag% doesn't exist, *_parse_song_info* prints:

`title: song title`

By default, if no format string is given, *_parse_song_info* displays song's filepath.  

Available metadata are:

*  %file%
*  %ext%
*  %last-modified%
*  %artist%
*  %name%
*  %album%
*  %albumartist% (defaults to %artist% if not found)
*  %title%
*  %track%
*  %genre%
*  %date%
*  %time%
*  %duration%
*  %pos%
*  %id%

### get_current, get_next, get_previous

Usage: `get_current [format]`  
Usage: `get_next [format]`  
Usage: `get_previous [format]`

Display specific info about current, next or previous song in the current queue.

### get_info

Usage: `get_info <uri> [format]`

Display specific info for given **uri**.

### get_duration, get_elapsed

Usage: `get_duration [-h]`  
Usage: `get_elapsed [-h]`

Display song duration or elapsed time in seconds.  
`-h` print time in a human readable format.

### _album_uri

Usage: `_album_uri [uri]`

Strip filename part from current song path or given **uri**.

### get_music_dir

Print music directory location from **mpd** config command. If it fails, reads from **smpcp** settings.

Exit status: 0 success, 1 failed.

### get_albumart

Usage: `get_album_art [uri]`

Searches for album art image files (cover.jpg, cover.png, folder.jpg, folder.png), creates a 64x64 pixels thumbnail and save it to `$XDG_HOME_CONFIG/smpcp/.cache` and print its path.

If no image file could be found, the function prints the path of the default cover image file.

If a thumbnail already exists for this album, *get_album_art* prints its path.

# notify.sh

**notify.sh** contains notification functions.

## Functions

### notify_song

Usage: `notify_song [uri]`

Displays a notification including album art for the current song or the given **uri**.

## notify_player

Usage: `notify_player <message>`

Displays a notification with player status and a given message.


