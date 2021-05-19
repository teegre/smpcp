# sleeptimer

## Description

**sleeptimer** is a plugin for smpcp.

It pauses playback after a given period of time (in minutes.)

Note: **sleeptimer** won't activate if **smpcpd** is not running.

## Usage

`smpcp sleeptimer -n`  
`smpcp sleeptimer [-n] <duration>`  
`smpcp sleeptimer [-n] -t`  

## Options

If set manually, duration should range between 15 and 120 minutes.

*  **-n**, display a notification.
*  **-t**, switch duration: 30, 60, 90, 120 or off.
