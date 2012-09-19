PREFIX = /usr/local
BINDIR = $(PREFIX)/bin

all:
	:

install:
	mkdir -p $(BINDIR)
	cp -f facilitator facilitator-email-poller facilitator.cgi fac.py $(BINDIR)
	cp -f init.d/facilitator /etc/init.d/

clean:
	rm -f *.pyc

test:
	./facilitator-test

.PHONY: all install clean test
