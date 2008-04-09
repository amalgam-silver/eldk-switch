# Makefile for eldk-switch
#
# (C) 2007-2008 by Detlev Zundel <dzu@denx.de>, DENX Software Engineering GmbH
#

PREFIX  = /usr/local
BINDIR  = $(PREFIX)/bin
DATADIR = $(PREFIX)/share/eldk

INSTALL = /usr/bin/install

bin         = eldk-switch.sh
bin-patch   = eldk-map
data        = eldk-map.dat
data-extra  = eldk-map-local.dat

.PHONY:	install clean

install:
	$(INSTALL) -d $(BINDIR)
	$(INSTALL) $(bin) $(BINDIR)
	TMPFILE=/tmp/eldk-install-tmp.$$$$; \
	for to_patch in $(bin-patch); do \
	    sed "s|^DATADIR=.*\$$|DATADIR=$(DATADIR)|" < $$to_patch > $$TMPFILE; \
	    $(INSTALL) $$TMPFILE $(BINDIR)/$$to_patch; \
	done; \
	rm $$TMPFILE
	$(INSTALL) -d $(DATADIR)
	$(INSTALL) -m644 $(data) $(DATADIR)
	[ -f "$(data-extra)" ] && $(INSTALL) -m644 $(data-extra) $(DATADIR)

clean:
	rm -f *~
