PREFIX = /usr/local
BINDIR = $(PREFIX)/bin

VERSION = 0.2

CLIENT_DIST_FILES = flashproxy-client flashproxy-reg-http README LICENSE torrc

all:
	:

install:
	mkdir -p $(BINDIR)
	cp -f flashproxy-client flashproxy-reg-http facilitator $(BINDIR)

clean:
	rm -f *.pyc
	rm -rf dist

test:
	./flashproxy-client-test
	./flashproxy-test.js

DISTNAME = flashproxy-client-$(VERSION)
DISTDIR = dist/$(DISTNAME)
dist:
	rm -rf dist
	mkdir -p $(DISTDIR)
	cp -f $(CLIENT_DIST_FILES) $(DISTDIR)
	cd dist && zip -q -r -9 $(DISTNAME).zip $(DISTNAME)

dist/$(DISTNAME).zip: $(CLIENT_DIST_FILES)
	$(MAKE) dist

sign: dist/$(DISTNAME).zip
	cd dist && gpg --sign --detach-sign --armor $(DISTNAME).zip

.PHONY: all clean test dist sign
