PREFIX = /usr/local
BINDIR = $(PREFIX)/bin

VERSION = 0.0

CLIENT_DIST_FILES = flashproxy-client.py flashproxy-reg-http.py README

all:
	:

install:
	mkdir -p $(BINDIR)
	cp -f flashproxy-client.py flashproxy-reg-http.py facilitator.py $(BINDIR)

clean:
	rm -f *.pyc
	rm -rf dist

test:
	./flashproxy-client-test.py
	./flashproxy-test.js

DISTNAME = flashproxy-client-$(VERSION)
DISTDIR = dist/$(DISTNAME)
dist/$(DISTNAME).zip:
	rm -rf dist
	mkdir -p $(DISTDIR)
	cp -f $(CLIENT_DIST_FILES) $(DISTDIR)
	cd dist && zip -q -r -9 $(DISTNAME).zip $(DISTNAME)

dist: dist/$(DISTNAME).zip

sign: dist/$(DISTNAME).zip
	cd dist && gpg --sign --detach-sign --armor $(DISTNAME).zip

.PHONY: all clean test dist sign
