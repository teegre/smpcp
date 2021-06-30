# shellcheck shell=bash

#
# .▄▄ · • ▌ ▄ ·.  ▄▄▄· ▄▄·  ▄▄▄· super
# ▐█ ▀. ·██ ▐███▪▐█ ▄█▐█ ▌▪▐█ ▄█ music
# ▄▀▀▀█▄▐█ ▌▐▌▐█· ██▀·██ ▄▄ ██▀· player
# ▐█▄▪▐███ ██▌▐█▌▐█▪·•▐███▌▐█▪·• client
#  ▀▀▀▀ ▀▀  █▪▀▀▀.▀   ·▀▀▀ .▀    plus+
#
# This file is a smpcp plugin.
# Copyright (C) 2021, Stéphane MEYER.
#
# Smpcp is free software: you can redistribute it and/or modify
# it under the terms of the GNU General Public License as published by
# the Free Software Foundation, either version 3 of the License, or
# (at your option) any later version.
#
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.
# See the GNU General Public License for more details.
#
# You should have received a copy of the GNU General Public License
# along with this program. If not, see <https://www.gnu.org/licenses/>
#
# PLUGIN EXAMPLE
# C : 2021/04/29
# M : 2021/06/30
# D : Basic plugin example.

# set version
export PLUG_HELLO_VERSION="0.1"

help_hello() {
  # use this function to add arguments and a short description.
  # syntax is: args=[arguments]; desc=<description>
  # this text will show in the smpcp help screen.

  echo "args=[name]; desc=either greets someone or the whole world."
}

plug_hello() {
  # this function will be available as a smpcp command.

  if [[ $1 ]]; then
    echo "Hello, ${1^}!"
  else
    echo "Hello, World!"
  fi
}

help_goodbye() {
  echo "args=[name]; desc=say goodbye to someone or to the whole world."
}

plug_goodbye() {
  # another function.

  if [[ $1 ]]; then
    echo "Goodbye, ${1^}!"
  else
    echo "Goodbye, World!"
  fi
}

__plug_hello_notify() {
   # here player event is passed as an argument to this function.
   case $1 in
     start ) echo "hello!" ;;
     play  ) echo "hello: playback started" ;;
     pause ) echo "hello: playback paused"  ;;
     stop  ) echo "hello: playback stopped" ;;
     change) echo "hello: a new song is playing" ;;
     end   ) echo "hello: reached the end of song" ;;
     add   ) echo "hello: adding new songs" ;;
     quit  ) echo "goodbye"
   esac
}
