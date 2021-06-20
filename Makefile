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
install: src/$(PROGNAME)
install: src/$(DAEMON)

	install -d  $(DESTDIR)$(BINDIR)
	
	install -m755 src/$(PROGNAME) $(DESTDIR)$(BINDIR)/$(PROGNAME)
	install -m755 src/$(DAEMON) $(DESTDIR)$(BINDIR)/$(DAEMON)
	
	${CC} src/idle.c $(LIBS) -o src/idlecmd
	install -m755 src/idlecmd $(DESTDIR)$(BINDIR)

	install -m644 $(SERVICE) $(SYSDUNIT)/$(SERVICE)

	install -Dm644 src/lib/*.* -t $(DESTDIR)$(LIBDIR)/$(PROGNAME)
	install -Dm644 smpcp.conf  -t $(DESTDIR)$(CONFIGDIR)/$(PROGNAME)
	install -Dm644 assets/*.*  -t $(DESTDIR)$(ASSETSDIR)/
	install -m644 autocomplete/bash-smpcp-complete $(DESTDIR)$(BASHCOMP)/$(PROGNAME)
	install -m644 autocomplete/zsh-smpcp-complete $(DESTDIR)$(ZSHCOMP)/_$(PROGNAME)
	install -Dm644 $(MANPAGE1) -t $(DESTDIR)$(MANDIR1)
	install -Dm644 $(MANPAGE5) -t $(DESTDIR)$(MANDIR5)
	install -Dm644 LICENSE     -t $(DESTDIR)$(SHAREDIR)/licenses/$(PROGNAME)

	rm src/$(PROGNAME)
	rm src/$(DAEMON)
	rm src/idlecmd

.PHONY: uninstall
uninstall:
	rm $(DESTDIR)$(BINDIR)/$(PROGNAME)
	rm $(DESTDIR)$(BINDIR)/$(DAEMON)
	rm $(DESTDIR)$(BINDIR)/idlecmd
	rm $(SYSDUNIT)/$(SERVICE)
	rm -rf $(DESTDIR)$(LIBDIR)/$(PROGNAME)
	rm -rf $(DESTDIR)$(CONFIGDIR)/$(PROGNAME)
	rm $(DESTDIR)$(BASHCOMP)/$(PROGNAME)
	rm $(DESTDIR)$(ZSHCOMP)/_$(PROGNAME)
	rm $(DESTDIR)$(MANDIR1)/$(MANPAGE1)
	rm $(DESTDIR)$(MANDIR5)/$(MANPAGE5)
	rm -rf $(DESTDIR)$(SHAREDIR)/licenses/$(PROGNAME)
