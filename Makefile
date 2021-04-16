PROGNAME  ?= smpcp
PREFIX    ?= /usr
BINDIR    ?= $(PREFIX)/bin
LIBDIR    ?= $(PREFIX)/lib
SHAREDIR  ?= $(PREFIX)/share
MANDIR    ?= $(SHAREDIR)/man/man1
CONFIGDIR ?= /etc
ASSETSDIR ?= $(CONFIGDIR)/$(PROGNAME)/assets
MANPAGE    = $(PROGNAME).1

CC         = gcc
LIBS       = -lmpdclient

.PHONY: install
install: src/$(PROGNAME).out
	install -d  $(DESTDIR)$(BINDIR)

	install -m755  src/$(PROGNAME).out $(DESTDIR)$(BINDIR)/$(PROGNAME)
	
	${CC} src/idle.c $(LIBS) -o src/idlecmd
	install -m755 src/idlecmd $(DESTDIR)$(BINDIR)

	install -m755 src/smpcpd $(DESTDIR)$(BINDIR)

	install -Dm644 src/*.sh   -t $(DESTDIR)$(LIBDIR)/$(PROGNAME)
	install -Dm644 settings   -t $(DESTDIR)$(CONFIGDIR)/$(PROGNAME)
	install -Dm644 assets/*.* -t $(DESTDIR)$(ASSETSDIR)/
	install -Dm644 $(MANPAGE) -t $(DESTDIR)$(MANDIR)
	install -Dm644 LICENSE    -t $(DESTDIR)$(SHAREDIR)/licenses/$(PROGNAME)

	rm src/$(PROGNAME).out
	rm src/idlecmd

.PHONY: uninstall
uninstall:
	rm $(DESTDIR)$(BINDIR)/$(PROGNAME)
	rm $(DESTDIR)$(BINDIR)/idlecmd
	rm $(DESTDIR)$(BINDIR)/smpcpd
	rm -rf $(DESTDIR)$(LIBDIR)/$(PROGNAME)
	rm -rf $(DESTDIR)$(CONFIGDIR)/$(PROGNAME)
	rm $(DESTDIR)$(MANDIR)/$(MANPAGE)
	rm -rf $(DESTDIR)$(SHAREDIR)/licenses/$(PROGNAME)
