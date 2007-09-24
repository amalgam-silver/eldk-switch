# Makefile for switch-eldk
#
# (C) 2007 by Detlev Zundel <dzu@denx.de>, DENX Software Engineering GmbH
#

PREFIX = /usr/local
BINDIR = $(PREFIX)/bin
LIBDIR = $(PREFIX)/lib

INSTALL = /usr/bin/install

bin = switch-eldk.sh eldk-map

.PHONY:	install clean

install:
	$(INSTALL) $(bin) $(BINDIR)

clean:
	rm -f *~
