PREFIX = /usr/local
BINDIR = $(PREFIX)/bin

all:
	:

install:
	mkdir -p $(BINDIR)
	cp -f facilitator facilitator.cgi fac.py $(BINDIR)

clean:
	rm -f *.pyc

test:
	./facilitator-test

.PHONY: all install clean test
