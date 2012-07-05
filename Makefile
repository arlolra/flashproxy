PREFIX = /usr/local
BINDIR = $(PREFIX)/bin

all:
	:

install:
	mkdir -p $(BINDIR)
	cp -f connector.py facilitator.py flashproxy-reg-http.py $(BINDIR)

clean:
	rm -f *.pyc

test:
	./connector-test.py
	./flashproxy-test.js

.PHONY: all clean test
