# alarm

## Description

**alarm** is a plugin for smpcp.

It starts playing music at a given date/time.

Note: **alarm** won't work if **smpcpd** is not running.

## Usage

`smpcp alarm [status]`  
`smpcp alarm set <date> [url]`  
`smpcp alarm cancel`

## Options

*  `status` - show alarm status.
*  `set`    - set an alarm.
*  `cancel` - cancel alarm.

## Examples

Set an alarm for tomorrow at 7:30:

`smpcp alarm set "tomorrow 7:30" "http://ice6.somafm.com/digitalis-128-mp3"`


Set an alarm for March 15, 2024 at 9pm :

`smpcp alarm set "2024/03/15 9pm"`
