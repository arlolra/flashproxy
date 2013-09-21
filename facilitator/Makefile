PREFIX = /usr/local
BINDIR = $(PREFIX)/bin

all:
	:

install:
	mkdir -p $(BINDIR)
	cp -f facilitator facilitator-email-poller facilitator-reg-daemon facilitator-reg facilitator.cgi fac.py $(BINDIR)
	mkdir -p /etc/flashproxy
	cp -f relays /etc/flashproxy
	cp -f init.d/facilitator init.d/facilitator-email-poller init.d/facilitator-reg-daemon /etc/init.d/

clean:
	rm -f *.pyc

test:
	./facilitator-test

.PHONY: all install clean test
