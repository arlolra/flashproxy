PREFIX = /usr/local
BINDIR = $(PREFIX)/bin

all:
	:

install:
	mkdir -p $(BINDIR)
	cp -f connector.py facilitator.py $(BINDIR)

clean:
	:

test:
	./connector-test.py
	./flashproxy-test.js

.PHONY: all clean test
