PREFIX = /usr/local
BINDIR = $(PREFIX)/bin
MANDIR = $(PREFIX)/share/man

VERSION = 0.8

CLIENT_BIN = flashproxy-client flashproxy-reg-email flashproxy-reg-http
CLIENT_MAN = doc/flashproxy-client.1 doc/flashproxy-reg-email.1 doc/flashproxy-reg-http.1
CLIENT_DIST_FILES = $(CLIENT_BIN) README LICENSE torrc

all: $(CLIENT_DIST_FILES) $(CLIENT_MAN)
	:

%.1: %.1.txt
	rm -f $@
	a2x --no-xmllint --xsltproc-opts "--stringparam man.th.title.max.length 23" \
		-d manpage -f manpage $<

install:
	mkdir -p $(BINDIR)
	mkdir -p $(MANDIR)/man1
	cp -f $(CLIENT_BIN) $(BINDIR)
	cp -f $(CLIENT_MAN) $(MANDIR)/man1

clean:
	rm -f *.pyc
	rm -rf dist

test:
	./flashproxy-client-test
	cd facilitator && ./facilitator-test
	cd proxy && ./flashproxy-test.js

DISTNAME = flashproxy-client-$(VERSION)
DISTDIR = dist/$(DISTNAME)
dist: $(CLIENT_MAN)
	rm -rf dist
	mkdir -p $(DISTDIR)
	mkdir $(DISTDIR)/doc
	cp -f $(CLIENT_DIST_FILES) $(DISTDIR)
	cp -f $(CLIENT_MAN) $(DISTDIR)/doc
	cd dist && zip -q -r -9 $(DISTNAME).zip $(DISTNAME)

dist/$(DISTNAME).zip: $(CLIENT_DIST_FILES)
	$(MAKE) dist

sign: dist/$(DISTNAME).zip
	rm -f dist/$(DISTNAME).zip.asc
	cd dist && gpg --sign --detach-sign --armor $(DISTNAME).zip
	cd dist && gpg --verify $(DISTNAME).zip.asc $(DISTNAME).zip

.PHONY: all install clean test dist sign
