PREFIX = /usr/local
BINDIR = $(PREFIX)/bin

all:
	:

install:
	mkdir -p $(BINDIR)
	cp -f flashproxy-client.py flashproxy-reg-http.py facilitator.py $(BINDIR)

clean:
	rm -f *.pyc

test:
	./flashproxy-client-test.py
	./flashproxy-test.js

.PHONY: all clean test
