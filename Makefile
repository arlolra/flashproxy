VERSION = 1.0

PREFIX = /usr/local
BINDIR = $(PREFIX)/bin
MANDIR = $(PREFIX)/share/man

PYTHON = python
export PY2EXE_TMPDIR = py2exe-tmp

CLIENT_BIN = flashproxy-client flashproxy-reg-email flashproxy-reg-http flashproxy-reg-url
CLIENT_MAN = doc/flashproxy-client.1 doc/flashproxy-reg-email.1 doc/flashproxy-reg-http.1 doc/flashproxy-reg-url.1
CLIENT_DIST_FILES = $(CLIENT_BIN) README LICENSE ChangeLog torrc
CLIENT_DIST_DOC_FILES = $(CLIENT_MAN) doc/LICENSE.PYTHON

all: $(CLIENT_DIST_FILES) $(CLIENT_MAN)
	:

%.1: %.1.txt
	rm -f $@
	a2x --no-xmllint --xsltproc-opts "--stringparam man.th.title.max.length 23" -d manpage -f manpage $<

install:
	mkdir -p $(BINDIR)
	mkdir -p $(MANDIR)/man1
	cp -f $(CLIENT_BIN) $(BINDIR)
	cp -f $(CLIENT_MAN) $(MANDIR)/man1

DISTNAME = flashproxy-client-$(VERSION)
DISTDIR = dist/$(DISTNAME)
dist: $(CLIENT_MAN)
	rm -rf dist
	mkdir -p $(DISTDIR)
	mkdir $(DISTDIR)/doc
	cp -f $(CLIENT_DIST_FILES) $(DISTDIR)
	cp -f $(CLIENT_DIST_DOC_FILES) $(DISTDIR)/doc
	cd dist && zip -q -r -9 $(DISTNAME).zip $(DISTNAME)

dist/$(DISTNAME).zip: $(CLIENT_DIST_FILES)
	$(MAKE) dist

sign: dist/$(DISTNAME).zip
	rm -f dist/$(DISTNAME).zip.asc
	cd dist && gpg --sign --detach-sign --armor $(DISTNAME).zip
	cd dist && gpg --verify $(DISTNAME).zip.asc $(DISTNAME).zip

$(PY2EXE_TMPDIR)/dist: $(CLIENT_BIN)
	rm -rf $(PY2EXE_TMPDIR)
	$(PYTHON) setup.py py2exe -q

# See doc/windows-deployment-howto.txt.
dist-exe: DISTNAME := $(DISTNAME)-win32
dist-exe: CLIENT_BIN := $(PY2EXE_TMPDIR)/dist/*
dist-exe: CLIENT_MAN := $(addsuffix .txt,$(CLIENT_MAN))
# Delegate to the "dist" target using the substitutions above.
dist-exe: $(PY2EXE_TMPDIR)/dist setup.py dist

clean:
	rm -f *.pyc
	rm -rf dist $(PY2EXE_TMPDIR)

test:
	./flashproxy-client-test
	cd facilitator && ./facilitator-test
	cd proxy && ./flashproxy-test.js

.PHONY: all install dist sign dist-exe clean test
