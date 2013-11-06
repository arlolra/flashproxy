# Makefile for a self-contained binary distribution of flashproxy-client.
#
# This builds two zipball targets, dist and dist-exe, for POSIX and Windows
# respectively. Both can be extracted and run in-place by the end user.
# (PGP-signed forms also exist, sign and sign-exe.)
#
# If you are a distro packager, instead see the separate build scripts for each
# source component, all of which have an `install` target:
# - client: Makefile.client
# - common: setup-common.py
# - facilitator: facilitator/{configure.ac,Makefile.am}
#
# Not for the faint-hearted: it is possible to build dist-exe on GNU/Linux by
# using wine to install the windows versions of Python, py2exe, and m2crypto,
# then running `make PYTHON_W32="wine python" dist-exe`.

PACKAGE = flashproxy-client
VERSION = 1.4
DISTNAME = $(PACKAGE)-$(VERSION)

THISFILE = $(lastword $(MAKEFILE_LIST))
PYTHON = python
PYTHON_W32 = $(PYTHON)

MAKE_CLIENT = $(MAKE) -f Makefile.client PYTHON="$(PYTHON)"
# don't rebuild man pages due to VCS giving spurious timestamps, see #9940
REBUILD_MAN = 0

# all is N/A for a binary package, but include for completeness
all: dist

DISTDIR = dist/$(DISTNAME)
$(DISTDIR): Makefile.client setup-common.py $(THISFILE)
	mkdir -p $(DISTDIR)
	$(MAKE_CLIENT) DESTDIR=$(DISTDIR) bindir=/ docdir=/ man1dir=/doc/ \
	  REBUILD_MAN="$(REBUILD_MAN)" install
	$(PYTHON) setup-common.py build_py -d $(DISTDIR)

dist/%.zip: dist/%
	cd dist && zip -q -r -9 "$(@:dist/%=%)" "$(<:dist/%=%)"

dist/%.zip.asc: dist/%.zip
	rm -f "$@"
	gpg --sign --detach-sign --armor "$<"
	gpg --verify "$@" "$<"

dist: force-dist $(DISTDIR).zip

sign: force-dist $(DISTDIR).zip.asc

PY2EXE_TMPDIR = py2exe-tmp
export PY2EXE_TMPDIR
$(PY2EXE_TMPDIR): setup-client-exe.py
	$(PYTHON_W32) setup-client-exe.py py2exe -q

DISTDIR_W32 = $(DISTDIR)-win32
# below, we override DST_SCRIPT and DST_MAN1 for windows
$(DISTDIR_W32): $(PY2EXE_TMPDIR) $(THISFILE)
	mkdir -p $(DISTDIR_W32)
	$(MAKE_CLIENT) DESTDIR=$(DISTDIR_W32) bindir=/ docdir=/ man1dir=/doc/ \
	  DST_SCRIPT= DST_MAN1='$$(SRC_MAN1)' \
	  REBUILD_MAN="$(REBUILD_MAN)" install
	cp -t $(DISTDIR_W32) $(PY2EXE_TMPDIR)/dist/*

dist-exe: force-dist-exe $(DISTDIR_W32).zip

sign-exe: force-dist-exe $(DISTDIR_W32).zip.asc

# clean is N/A for a binary package, but include for completeness
clean: distclean

distclean:
	$(MAKE_CLIENT) clean
	$(PYTHON) setup-common.py clean --all
	rm -rf dist $(PY2EXE_TMPDIR)

test: check
check:
	$(MAKE_CLIENT) check
	$(PYTHON) setup-common.py test
	cd facilitator && ./facilitator-test
	cd proxy && ./flashproxy-test.js

force-dist:
	rm -rf $(DISTDIR) $(DISTDIR).zip

force-dist-exe:
	rm -rf $(DISTDIR_W32) $(DISTDIR_W32).zip $(PY2EXE_TMPDIR)

.PHONY: all dist sign dist-exe sign-exe clean distclean test check force-dist force-dist-exe
