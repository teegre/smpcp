//
// .▄▄ · • ▌ ▄ ·.  ▄▄▄· ▄▄·  ▄▄▄· super
// ▐█ ▀. ·██ ▐███▪▐█ ▄█▐█ ▌▪▐█ ▄█ music
// ▄▀▀▀█▄▐█ ▌▐▌▐█· ██▀·██ ▄▄ ██▀· player
// ▐█▄▪▐███ ██▌▐█▌▐█▪·•▐███▌▐█▪·• client
//  ▀▀▀▀ ▀▀  █▪▀▀▀.▀   ·▀▀▀ .▀    plus+
//
// This file is part of smpcp.
// Copyright (C) 2021, Stéphane MEYER.
//
// Smpcp is free software: you can redistribute it and/or modify
// it under the terms of the GNU General Public License as published by
// the Free Software Foundation, either version 3 of the License, or
// (at your option) any later version.
//
// This program is distributed in the hope that it will be useful,
// but WITHOUT ANY WARRANTY; without even the implied warranty of
// MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.
// See the GNU General Public License for more details.
//
// You should have received a copy of the GNU General Public License
// along with this program. If not, see <https://www.gnu.org/licenses/>
//
// IDLE
// C : 2021/04/07
// M : 2021/04/07
// D : Idle command.

#include "mpd/client.h"

#include <stdio.h>
#include <string.h>


int idle_cmd(int argc, char **argv, struct mpd_connection *c) {

  enum mpd_idle idle = 0;

  for (int i = 1; i < argc; ++i) {
    if (strcmp(argv[i], "loop") == 0)
      continue;
    enum mpd_idle parsed = mpd_idle_name_parse(argv[i]);
    if (parsed == 0) {
      fprintf(stderr, "bad idle event \"%s\".\n", argv[i]);
      return 1;
    }
    idle |= parsed;
  }

  idle = idle == 0 ? mpd_run_idle(c) : mpd_run_idle_mask(c, idle);

  if (idle == 0 && mpd_connection_get_error(c) != MPD_ERROR_SUCCESS) {
    printf("could not connect!\n");
    return 1;
  }

  for (unsigned j = 0;; ++j) {
    enum mpd_idle i = 1 << j;
    const char *name = mpd_idle_name(i);

    if (name == NULL)
      break;

    if (idle & i)
      printf("%s\n", name);
  }

  return 0;
}

int idle_loop(int argc, char **argv, struct mpd_connection *c) {
  while (true) {
    int ret = idle_cmd(argc, argv, c);
    fflush(stdout);
    if (ret != 0)
      return ret;
  }
}

int main(int argc, char **argv) {
  
  struct mpd_connection *c = mpd_connection_new(NULL, 0, 0);
  int ret = 0;
   
  if (argc > 1) {
    if (strcmp(argv[1], "loop") == 0)
      ret = idle_loop(argc, argv, c);
    else
      ret = idle_cmd(argc, argv, c);
  } else
    ret = idle_cmd(argc, argv, c);

  mpd_connection_free(c);
  return ret;
}
