```
.▄▄ · • ▌ ▄ ·.  ▄▄▄· ▄▄·  ▄▄▄· super
▐█ ▀. ·██ ▐███▪▐█ ▄█▐█ ▌▪▐█ ▄█ music
▄▀▀▀█▄▐█ ▌▐▌▐█· ██▀·██ ▄▄ ██▀· player
▐█▄▪▐███ ██▌▐█▌▐█▪·•▐███▌▐█▪·• client
 ▀▀▀▀ ▀▀  █▪▀▀▀.▀   ·▀▀▀ .▀    plus+
```

# SMPCP

## Description

**smpcp** is a command line client for [Music Player Daemon](https://www.musicpd.org) written in Bash (and a little C), that includes some more advanced features like:

*  Auto-generated playlists (song and album modes).
*  Notifications (with album art).
*  Song rating.
*  Playback statistics.
*  Can be extended with plugins.

## Dependencies

Latest version of these packages are needed:
awk (for auto-completion)  
bash  
cdparanoia (optional)  
coreutils  
openbsd-netcat  
imagemagick  
libmpdclient  
libnotify  
mpd  
sed (for auto-completion)  
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
As a starting point, a default configuration file called **smpcp.conf** can be found in `/etc/smpcp` directory:

`mkdir $HOME/.config/smpcp`

`cp /etc/smpcp/smpcp.conf ~/.config/smpcp`

For more info, read **smpcp.conf(5)** manual page.

## Daemon

To enable auto-playlists and playback statistics, **smpcpd** - the **smpcp** daemon - must be running. A systemd unit is provided for this purpose.

To enable the daemon:

`systemctl --user enable smpcpd`

To start the daemon:

`systemctl --user start smpcpd`.

## Usage

To execute a command: `smpcp <command> [options]`

Commands can be chained with the `++` operator: `smpcp clear ++ add kraftwerk/autobahn ++ play`

To see a list of available commands: `smpcp help`

For more info, read **smpcp(1)** manual page.

## Plugins

As stated at the beginning of this document, **smpcp** can be extended with plugins (check out `plugins` in this repository).

Until I find a convenient way to manage plugin installation, a plugin must be installed manually by copying or symlinking its directory over to `$XDG_CONFIG_HOME/smpcp/plugins/`.
No extra step is needed since **smpcp** 'detects' plugins automatically.

Type `smpcp plugins` to see a list of installed plugins.

### Writing plugins

I provided a (very basic and still in construction) guide to help plugins development: [Plugins Development Guide Wiki](https://gitlab.com/teegre/smpcp/-/wikis/Plugin-Development-Guide)  
And you can check out the example plugin called **hello**.

