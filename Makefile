PROGNAME  ?= smpcp
DAEMON    ?= smpcpd
SERVICE   ?= smpcpd.service
PREFIX    ?= /usr
BINDIR    ?= $(PREFIX)/bin
LIBDIR    ?= $(PREFIX)/lib
SYSDUNIT  ?= $(LIBDIR)/systemd/system
SHAREDIR  ?= $(PREFIX)/share
MANDIR    ?= $(SHAREDIR)/man/man1
CONFIGDIR ?= /etc
ASSETSDIR ?= $(CONFIGDIR)/$(PROGNAME)/assets
MANPAGE    = $(PROGNAME).1

CC         = gcc
LIBS       = -lmpdclient

.PHONY: install
install: src/$(PROGNAME)
install: src/$(DAEMON)

	install -d  $(DESTDIR)$(BINDIR)
	
	install -m755 src/$(PROGNAME) $(DESTDIR)$(BINDIR)/$(PROGNAME)
	install -m755 src/$(DAEMON) $(DESTDIR)$(BINDIR)
	
	${CC} src/idle.c $(LIBS) -o src/idlecmd
	install -m755 src/idlecmd $(DESTDIR)$(BINDIR)

	install -Dm644 $(SERVICE)  -t $(SYSDUNIT)/$(SERVICE)
	install -Dm644 src/lib/*.* -t $(DESTDIR)$(LIBDIR)/$(PROGNAME)
	install -Dm644 settings    -t $(DESTDIR)$(CONFIGDIR)/$(PROGNAME)
	install -Dm644 assets/*.*  -t $(DESTDIR)$(ASSETSDIR)/
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
	rm $(DESTDIR)$(MANDIR)/$(MANPAGE)
	rm -rf $(DESTDIR)$(SHAREDIR)/licenses/$(PROGNAME)
