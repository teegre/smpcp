PROGNAME  ?= smpcp
DAEMON    ?= smpcpd
SERVICE   ?= smpcpd.service
PREFIX    ?= /usr
BINDIR    ?= $(PREFIX)/bin
LIBDIR    ?= $(PREFIX)/lib
SYSDUNIT  ?= $(LIBDIR)/systemd/user
SHAREDIR  ?= $(PREFIX)/share
MANDIR1   ?= $(SHAREDIR)/man/man1
MANDIR5   ?= $(SHAREDIR)/man/man5
CONFIGDIR ?= /etc
ASSETSDIR ?= $(CONFIGDIR)/$(PROGNAME)/assets
BASHCOMP  ?= $(SHAREDIR)/bash-completion/completions
ZSHCOMP   ?= $(SHAREDIR)/zsh/functions/Completion/Unix
MANPAGE1   = $(PROGNAME).1
MANPAGE5   = $(PROGNAME).conf.5

CC         = gcc
LIBS       = -lmpdclient

.PHONY: install
install:src/$(PROGNAME)
install:src/$(DAEMON)
	install -d $(BINDIR)
	install -m755 src/$(PROGNAME) $(BINDIR)/$(PROGNAME)
	install -m755 src/$(DAEMON) $(BINDIR)/$(DAEMON)
	${CC} src/idle.c $(LIBS) -o src/idlecmd
	install -m755 src/idlecmd $(BINDIR)
	install -m644 $(SERVICE) $(SYSDUNIT)/$(SERVICE)
	install -Dm644 src/lib/*.* -t $(LIBDIR)/$(PROGNAME)
	install -Dm644 smpcp.conf  -t $(CONFIGDIR)/$(PROGNAME)
	install -Dm644 assets/*.*  -t $(ASSETSDIR)/
	install -Dm644 $(MANPAGE1) -t $(MANDIR1)
	install -Dm644 $(MANPAGE5) -t $(MANDIR5)
	install -Dm644 LICENSE     -t $(SHAREDIR)/licenses/$(PROGNAME)
	if [ -d $(BASHCOMP) ]; then install -m644 autocomplete/bash-smpcp-complete $(BASHCOMP)/$(PROGNAME); fi
	if [ -d $(ZSHCOMP) ]; then install -m644 autocomplete/zsh-smpcp-complete $(ZSHCOMP)/_$(PROGNAME); fi
	rm src/$(PROGNAME)
	rm src/$(DAEMON)
	rm src/idlecmd

.PHONY: uninstall
uninstall:
	rm $(BINDIR)/$(PROGNAME)
	rm $(BINDIR)/$(DAEMON)
	rm $(BINDIR)/idlecmd
	rm $(SYSDUNIT)/$(SERVICE)
	rm -rf $(LIBDIR)/$(PROGNAME)
	rm -rf $(CONFIGDIR)/$(PROGNAME)
	rm $(MANDIR1)/$(MANPAGE1)
	rm $(MANDIR5)/$(MANPAGE5)
	rm -rf $(SHAREDIR)/licenses/$(PROGNAME)
	if [ -d $(BASHCOMP) ]; then rm $(BASHCOMP)/$(PROGNAME); fi
	if [ -d $(ZSHCOMP) ]; then rm $(ZSHCOMP)/_$(PROGNAME); fi
