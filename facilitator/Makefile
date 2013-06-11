PREFIX = /usr/local
BINDIR = $(PREFIX)/bin

all:
	:

install:
	mkdir -p $(BINDIR)
	cp -f facilitator facilitator-email-poller facilitator-reg-daemon facilitator-reg facilitator.cgi fac.py ordereddict.py $(BINDIR)
	cp -f init.d/facilitator init.d/facilitator-email-poller init.d/facilitator-reg-daemon /etc/init.d/

clean:
	rm -f *.pyc

test:
	./facilitator-test

.PHONY: all install clean test
