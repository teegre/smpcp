PROGNAME  ?= smpcp
DAEMON    ?= smpcpd
SERVICE   ?= smpcpd.service
PREFIX    ?= /usr
BINDIR    ?= $(PREFIX)/bin
LIBDIR    ?= $(PREFIX)/lib
SYSDUNIT  ?= $(LIBDIR)/systemd/user
SHAREDIR  ?= $(PREFIX)/share
MANDIR    ?= $(SHAREDIR)/man/man1
CONFIGDIR ?= /etc
ASSETSDIR ?= $(CONFIGDIR)/$(PROGNAME)/assets
BASHCOMP  ?= $(SHAREDIR)/bash-completion/completions
ZSHCOMP   ?= $(SHAREDIR)/zsh/functions/Completion/Unix
MANPAGE    = $(PROGNAME).1

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
	install -Dm644 settings    -t $(DESTDIR)$(CONFIGDIR)/$(PROGNAME)
	install -Dm644 assets/*.*  -t $(DESTDIR)$(ASSETSDIR)/
	install -m644 autocomplete/smpcp-complete.sh $(DESTDIR)$(BASHCOMP)/$(PROGNAME)
	install -m644 autocomplete/zsh-smpcp-complete.sh $(DESTDIR)$(ZSHCOMP)/_$(PROGNAME)
	install -Dm644 $(MANPAGE)  -t $(DESTDIR)$(MANDIR)
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
	rm $(DESTDIR)$(MANDIR)/$(MANPAGE)
	rm -rf $(DESTDIR)$(SHAREDIR)/licenses/$(PROGNAME)
