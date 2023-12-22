# cassette

## Description

**cassette** is a plugin for smpcp.

It is a programmable audio recorder.

Note: **cassette** won't work if **smpcpd** is not running.

## Usage

`smpcp cassette [status]`  
`smpcp cassette start`  
`smpcp cassette stop`  
`smpcp cassette set <dur> <date> <url>`  
`smpcp cassette cancel`

## Configuration

In order to work, **cassette** needs *recorder* output plugin.

Add these lines to `mpd.conf`.

```
audio_output {
  type        "recorder"
  name        "recorder"
  enabled     "no"
  path        "~/.config/smpcp/plugins/cassette/cassette.ogg"
  encoder     "vorbis"
  format      "44100:16:2"
}
```

## Options

*  `start` - start recording current audio.
*  `stop` - stop recording.
*  `set` - schedule a recording.
*  `cancel` - cancel scheduled recording.

## Examples

Schedule a 60 minutes recording for tomorrow at 7:30

`smpcp cassette set 60 "tomorrow 7:30" "http://ice6.somafm.com/digitalis-128-mp3"`

Schedule a 120 minutes recording on June 7th at 9pm, assuming radio streams are stored in a playlist called `radios`

`smpcp cassette set 120 "2021/06/07 9pm" "$(smpcp pls radios 1)"`

## Recordings

If **smpcp** has access to the music directory, recorded files are stored in `music_dir/cassette` and they are also added to the  
`recordings` playlist. Otherwise, files are stored in **cassette** plugin directory, that is `$XDG_CONFIG_HOME/smpcp/plugins/cassette`.
