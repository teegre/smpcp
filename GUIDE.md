# PROGRAMMER'S GUIDE

This is a summary of available functions that can be useful when developing a plugin.

Libraries are stored in `/usr/lib/smpcp`.

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

`-x` sets netcat buffering output delay time to 1 second.  
It prevents netcat from prematurely returning while an expensive task is running (i.e listall).

### fcmd

Usage: `fcmd [-c] [-x] <mpd_command> [options] <key>`

Filters command output by printing value for a given key.

`-c` prints line count only.

`-x` see `cmd`.

### state

Usage: `state [-p]`

Returns exit status 0 if playing or paused, 1 if stopped.

`-p` prints actual state. Can be *play*, *pause* or *stop*.

### _parse_song_info

`Usage: _parse_song_info [-s] [format]`

Parses song information in the given format.

declare -f __album_mode
declare -f __is_mpd_running
declare -f __normal_mode
declare -f __song_mode
declare -f _album_uri
declare -f _daemon
declare -f _date
declare -f _db_get_all_songs
declare -f _db_get_history
declare -f _db_get_previous_song
declare -f _db_get_uri_by_rating
declare -f _db_rating_count
declare -f _help
declare -f _is_in_history
declare -f _is_in_playlist
declare -f _mode
declare -f _parse_song_info
declare -f _playback_mode
declare -f _print_version
declare -f _quote
declare -f _repeat
declare -f _wait
declare -f add
declare -f add_album
declare -f check_pid
declare -f clean_orphan_stickers
declare -f clear_media
declare -f clear_queue
declare -f cmd
declare -f consume
declare -f crop
declare -f db_playtime
declare -f delete
declare -f delete_sticker
declare -f dim
declare -f fcmd
declare -f find_sticker
declare -f get_album_info
declare -f get_albumart
declare -f get_all_plugin_functions
declare -f get_current
declare -f get_discography
declare -f get_duration
declare -f get_elapsed
declare -f get_ext
declare -f get_mode
declare -f get_music_dir
declare -f get_next
declare -f get_plugin_function
declare -f get_plugin_list
declare -f get_previous
declare -f get_random_song
declare -f get_rnd
declare -f get_sticker
declare -f get_uri_by_rating
declare -f is_in_queue
declare -f lastplayed
declare -f list_playlist
declare -f list_plugins
declare -f list_queue
declare -f load
declare -f logme
declare -f media_update
declare -f message
declare -f move
declare -f next
declare -f next_album
declare -f notify_volume
declare -f now
declare -f pause
declare -f play
declare -f playcount
declare -f plugin_function_exec
declare -f plugin_function_exists
declare -f plugin_help
declare -f plugin_notify
declare -f previous
declare -f pstatus
declare -f queue_is_empty
declare -f queue_length
declare -f random
declare -f rating
declare -f read_config
declare -f remove_config
declare -f replaygain
declare -f reset_stats
declare -f search
declare -f searchadd
declare -f secs_to_hms
declare -f seek
declare -f set_sticker
declare -f single
declare -f skip
declare -f skipcount
declare -f song_stats
declare -f state
declare -f status
declare -f stop
declare -f toggle
declare -f tracker
declare -f try_plugin
declare -f update
declare -f update_daemon
declare -f update_history_index
declare -f update_song_list
declare -f update_stats
declare -f volume
declare -f wait_for_pid
declare -f write_config
declare -f xfade
