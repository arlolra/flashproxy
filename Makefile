PREFIX = /usr/local
BINDIR = $(PREFIX)/bin

VERSION = 0.8

CLIENT_EXECUTABLES = flashproxy-client flashproxy-reg-email flashproxy-reg-http
CLIENT_ASCIIDOCS = $(CLIENT_EXECUTABLES:%=doc/%.1.txt)
CLIENT_MANPAGES = $(CLIENT_EXECUTABLES:%=doc/%.1)
CLIENT_DIST_FILES = $(CLIENT_EXECUTABLES) README LICENSE torrc

all:
	:

install:
	mkdir -p $(BINDIR)
	cp -f flashproxy-client flashproxy-reg-email flashproxy-reg-http $(BINDIR)

clean:
	rm -f *.pyc
	rm -rf dist

test:
	./flashproxy-client-test
	cd facilitator && ./facilitator-test
	cd proxy && ./flashproxy-test.js

DISTNAME = flashproxy-client-$(VERSION)
DISTDIR = dist/$(DISTNAME)
dist: $(CLIENT_MANPAGES)
	rm -rf dist
	mkdir -p $(DISTDIR)
	mkdir $(DISTDIR)/doc
	cp -f $(CLIENT_DIST_FILES) $(DISTDIR)
	cp -f $(CLIENT_MANPAGES) $(DISTDIR)/doc
	cd dist && zip -q -r -9 $(DISTNAME).zip $(DISTNAME)

dist/$(DISTNAME).zip: $(CLIENT_DIST_FILES)
	$(MAKE) dist

sign: dist/$(DISTNAME).zip
	rm -f dist/$(DISTNAME).zip.asc
	cd dist && gpg --sign --detach-sign --armor $(DISTNAME).zip
	cd dist && gpg --verify $(DISTNAME).zip.asc $(DISTNAME).zip

%.1: $(CLIENT_ASCIIDOCS)
	rm -rf $@
	a2x --no-xmllint --xsltproc-opts "--stringparam man.th.title.max.length 23" \
		-d manpage -f manpage $@.txt

.PHONY: all install clean test dist sign
