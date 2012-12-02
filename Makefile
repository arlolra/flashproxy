PREFIX = /usr/local
BINDIR = $(PREFIX)/bin
MANDIR = $(PREFIX)/share/man

PYTHON = python
PYINSTALLER_PY = ../pyinstaller-2.0/pyinstaller.py
export PYINSTALLER_TMPDIR = pyi

VERSION = 0.8

CLIENT_BIN = flashproxy-client flashproxy-reg-email flashproxy-reg-http
CLIENT_MAN = doc/flashproxy-client.1 doc/flashproxy-reg-email.1 doc/flashproxy-reg-http.1
CLIENT_DIST_FILES = $(CLIENT_BIN) README LICENSE torrc
CLIENT_DIST_DOC_FILES = $(CLIENT_MAN) doc/LICENSE.GPL doc/LICENSE.PYTHON

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
	rm -rf dist $(PYINSTALLER_TMPDIR)

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
	cp -f $(CLIENT_DIST_DOC_FILES) $(DISTDIR)/doc
	cd dist && zip -q -r -9 $(DISTNAME).zip $(DISTNAME)

dist/$(DISTNAME).zip: $(CLIENT_DIST_FILES)
	$(MAKE) dist

sign: dist/$(DISTNAME).zip
	rm -f dist/$(DISTNAME).zip.asc
	cd dist && gpg --sign --detach-sign --armor $(DISTNAME).zip
	cd dist && gpg --verify $(DISTNAME).zip.asc $(DISTNAME).zip

$(PYINSTALLER_TMPDIR)/dist: $(CLIENT_BIN)
	rm -rf $(PYINSTALLER_TMPDIR)
# PyInstaller writes "ERROR" to stderr (along with its other messages) when it
# fails to find a hidden import like M2Crypto, but continues anyway and doesn't
# change its error code. Grep for "ERROR" and stop if found.
	$(PYTHON) $(PYINSTALLER_PY) --buildpath=$(PYINSTALLER_TMPDIR)/build --log-level=WARN flashproxy-client.spec 2>&1 | tee /dev/tty | grep -q "ERROR"; test $$? == 1
	mv $(PYINSTALLER_TMPDIR)/dist/M2Crypto.__m2crypto.pyd $(PYINSTALLER_TMPDIR)/dist/__m2crypto.pyd
	rm -rf logdict*.log

# See doc/windows-deployment-howto.txt.
DISTNAME_WIN32 = $(DISTNAME)-win32
DISTDIR_WIN32 = $(DISTDIR)-win32
dist-exe: CLIENT_BIN := $(PYINSTALLER_TMPDIR)/dist/*
dist-exe: CLIENT_MAN := $(addsuffix .txt,$(CLIENT_MAN))
dist-exe: $(PYINSTALLER_TMPDIR)/dist flashproxy-client.spec
	rm -rf dist
	mkdir -p $(DISTDIR_WIN32)
	mkdir $(DISTDIR_WIN32)/doc
	cp -f $(CLIENT_DIST_FILES) $(DISTDIR_WIN32)
	cp -f $(CLIENT_DIST_DOC_FILES) $(DISTDIR_WIN32)/doc
	cd dist && zip -q -r -9 $(DISTNAME_WIN32).zip $(DISTNAME_WIN32)

.PHONY: all install clean test dist sign dist-exe
