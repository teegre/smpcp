# mute

## Description

**mute** is a plugin for smpcp.

It (un)mutes a given audio output.

## Usage

`smpcp mute`  
`smpcp mute <on|off>`

## Configuration

Add this entry to `$XDG_CONFIG_HOME/smpcp/smpcp.conf`:  

```
mute_output_name = outputname
```

Replace `outputname` with the name of the **mpd** output you want to use, and you're done.

