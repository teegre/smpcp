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


