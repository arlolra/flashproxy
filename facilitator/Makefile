DESTDIR =
PREFIX = /usr/local
BINDIR = $(PREFIX)/bin

all:
	:

install:
	mkdir -p $(DESTDIR)$(BINDIR)
	cp -f facilitator facilitator-email-poller facilitator-reg-daemon facilitator-reg facilitator.cgi fac.py $(DESTDIR)$(BINDIR)
	cp -f init.d/facilitator init.d/facilitator-email-poller init.d/facilitator-reg-daemon $(DESTDIR)/etc/init.d/

clean:
	rm -f *.pyc

test:
	./facilitator-test

.PHONY: all install clean test
