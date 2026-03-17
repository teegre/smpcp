//
// .▄▄ · • ▌ ▄ ·.  ▄▄▄· ▄▄·  ▄▄▄· super
// ▐█ ▀. ·██ ▐███▪▐█ ▄█▐█ ▌▪▐█ ▄█ music
// ▄▀▀▀█▄▐█ ▌▐▌▐█· ██▀·██ ▄▄ ██▀· player
// ▐█▄▪▐███ ██▌▐█▌▐█▪·•▐███▌▐█▪·• client
//  ▀▀▀▀ ▀▀  █▪▀▀▀.▀   ·▀▀▀ .▀    plus+
//
// This file is part of smpcp.
// Copyright (C) 2021-2026, Stéphane MEYER.
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
// M : 2026/03/17
// D : Idle command.

#include <errno.h>
#include <mpd/connection.h>
#include <mpd/error.h>
#include <mpd/idle.h>
#include <mpd/response.h>
#include <poll.h>
#include <signal.h>
#include <stdio.h>
#include <string.h>
#include <sys/poll.h>
#include <unistd.h>

#include "mpd/client.h"

static int pipefd[2];

void sig_handler(int sig) {
    write(pipefd[1], "x", 1);
    if (sig == SIGINT)
        fprintf(stderr, "\n");
}

void sig_set_handler(int sig, void (*handler)(int)) {
    struct sigaction sa;
    memset(&sa, 0, sizeof(sa));

    sigemptyset(&sa.sa_mask);
    sa.sa_handler = handler;
    sa.sa_flags = 0;

    sigaction(sig, &sa, NULL);
}

void sig_setup(void) {
    pipe(pipefd);

    sig_set_handler(SIGINT, sig_handler);
    sig_set_handler(SIGTERM, sig_handler);
    sig_set_handler(SIGQUIT, sig_handler);
}

void print_idle_events(enum mpd_idle idle) {
    for (unsigned j = 0;; ++j) {
        enum mpd_idle i = 1 << j;
        const char *name = mpd_idle_name(i);

        if (name == NULL)
            break;

        if (idle & i)
            printf("%s\n", name);
    }
}

int wait_idle(struct mpd_connection *c, enum mpd_idle mask, enum mpd_idle *out) {
    struct pollfd fds[2];
    int mpd_fd = mpd_connection_get_fd(c);

    fds[0].fd = mpd_fd;
    fds[0].events = POLLIN;

    fds[1].fd = pipefd[0];
    fds[1].events = POLLIN;

    if (mask == 0) {
        if (!mpd_send_idle(c))
            return -1;
    }
    else {
        if (!mpd_send_idle_mask(c, mask))
            return -1;
    }

    for (;;) {
        int ret;

        do {
            ret = poll(fds, 2, -1);
        } while (ret < 0 && errno == EINTR);

        if (ret < 0)
            return -1;

        if (fds[1].revents & POLLIN) {
            char buf[16];
            read(pipefd[0], buf, sizeof(buf));

            mpd_send_noidle(c);
            mpd_response_finish(c);
            return 1;
        }

        if (fds[0].revents & POLLIN) {
            enum mpd_idle idle = mpd_recv_idle(c, true);

            if (idle == 0 && mpd_connection_get_error(c) != MPD_ERROR_SUCCESS)
                return -1;

            if (!mpd_response_finish(c))
                return -1;

            *out = idle;
            return 0;
        }
    }
}

int idle_cmd(int argc, char **argv, struct mpd_connection *c) {

    enum mpd_idle mask = 0;

    for (int i = 1; i < argc; ++i) {
        if (strcmp(argv[i], "loop") == 0)
            continue;

        enum mpd_idle parsed = mpd_idle_name_parse(argv[i]);
        if (parsed == 0) {
            fprintf(stderr, "smpcp-idle: unknown event '%s'.\n", argv[i]);
            return 1;
        }

        mask |= parsed;
    }

    enum mpd_idle idle;
    int ret = wait_idle(c, mask, &idle);

    if (ret == 1) // interrupted
        return 2;

    if (ret != 0) {
        return 1;
    }

    print_idle_events(idle);
    return 0;
}

int idle_loop(int argc, char **argv, struct mpd_connection *c) {
    while (1) {
        int ret = idle_cmd(argc, argv, c);

        if (ret != 0)
            return ret;

        fflush(stdout);
    }
}

int main(int argc, char **argv) {
    struct mpd_connection *c = mpd_connection_new(NULL, 0, 0);
    int ret = 0;

    sig_setup();

    if (argc > 1) {
        if (strcmp(argv[1], "loop") == 0)
            ret = idle_loop(argc, argv, c);
        else
            ret = idle_cmd(argc, argv, c);
    }
    else
        ret = idle_cmd(argc, argv, c);

    mpd_connection_free(c);

    if (ret == 2)
        fprintf(stderr, "smpcp-idle: bye!\n");

    return ret;
}
