# shellcheck shell=bash

#
# .▄▄ · • ▌ ▄ ·.  ▄▄▄· ▄▄·  ▄▄▄· super
# ▐█ ▀. ·██ ▐███▪▐█ ▄█▐█ ▌▪▐█ ▄█ music
# ▄▀▀▀█▄▐█ ▌▐▌▐█· ██▀·██ ▄▄ ██▀· player
# ▐█▄▪▐███ ██▌▐█▌▐█▪·•▐███▌▐█▪·• client
#  ▀▀▀▀ ▀▀  █▪▀▀▀.▀   ·▀▀▀ .▀    plus+
#
# This file is part of smpcp.
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
# SMPCP-AUTOCOMPLETE
# C : 2021/04/13
# M : 2021/05/30
# D : Bash completion for smpcp.

_smpcp_cmd() {
  local cmds
  cmds="$(smpcp help | awk '/^ *smpcp [a-z]+ /{print $2" "}')"
  mapfile -t COMPREPLY < <(compgen -W "$cmds" -- "$cur")
}

_smpcp_dir() {
  cur="${cur//\\}" # !!!
  mapfile -t COMPREPLY < <(smpcp lsdir "$cur" 2> /dev/null | sort -u)
}

_smpcp_opt() {
  mapfile -t COMPREPLY < <(compgen -W "$*" -- "$cur")
}

_smpcp_pls() {
  mapfile -t COMPREPLY < <(smpcp pls 2> /dev/null)
}

_smpcp() {
  local cur prev
  _init_completion
  case $prev in
    add  ) _smpcp_dir ;;
    dim  ) _smpcp_opt "-n" ;;
    consume | random | repeat | single ) _smpcp_opt "on" "off" ;;
    cload | load ) _smpcp_pls ;;
    lsdir) _smpcp_dir ;;
    mode ) _smpcp_opt "album" "song" "normal" ;;
    replaygain) _smpcp_opt "auto" "album" "track" ;;
    *    ) _smpcp_cmd ;;
  esac
}

complete -o nospace -F _smpcp smpcp
