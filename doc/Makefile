BUNDLE_VERSION = 2.4.11
BUNDLE_RELEASE = alpha-2
PT_BUNDLE_RELEASE = pt1

FLASHPROXY_HOME = $(HOME)/flashproxy
FLASHPROXY_VERSION = 1.0
FLASHPROXY_DIST = $(FLASHPROXY_HOME)/dist/flashproxy-client-$(FLASHPROXY_VERSION)
PYOBFSPROXY_HOME = $(HOME)/pyobfsproxy
PYOBFSPROXY_DIST = $(PYOBFSPROXY_HOME)

DOWNLOADDIR = download
WORKDIR = work

BUNDLE_DIST_URL = https://www.torproject.org/dist/torbrowser

BUNDLE_VERSION_STRING = $(BUNDLE_VERSION)-$(BUNDLE_RELEASE)
PT_BUNDLE_VERSION_STRING = $(BUNDLE_VERSION)-$(BUNDLE_RELEASE)-$(PT_BUNDLE_RELEASE)

BUNDLE_GNULINUX_I686 = tor-browser-gnu-linux-i686-$(BUNDLE_VERSION_STRING)-dev-en-US.tar.gz
BUNDLE_GNULINUX_X86_64 = tor-browser-gnu-linux-x86_64-$(BUNDLE_VERSION_STRING)-dev-en-US.tar.gz

PT_BUNDLE_GNULINUX_I686 = tor-pluggable-transports-browser-gnu-linux-i686-$(PT_BUNDLE_VERSION_STRING)-dev-en-US.tar.gz
PT_BUNDLE_GNULINUX_X86_64 = tor-pluggable-transports-browser-gnu-linux-x86_64-$(PT_BUNDLE_VERSION_STRING)-dev-en-US.tar.gz

all:
	@echo "Try one of these:"
	@echo $$'\tmake gnulinux-i686'
	@echo $$'\tmake gnulinux-x86_64'
	@echo
	@echo "Configure version numbers at the top of this makefile."
	@echo "Before starting, you need to run \"make dist\" in the flashproxy directory."

gnulinux-i686: $(PT_BUNDLE_GNULINUX_I686)
gnulinux-x86_64: $(PT_BUNDLE_GNULINUX_X86_64)

$(PT_BUNDLE_GNULINUX_I686): WORKDIR = work/gnulinux-i686-$(PT_BUNDLE_VERSION_STRING)
$(PT_BUNDLE_GNULINUX_I686): BUNDLE_GNULINUX = $(BUNDLE_GNULINUX_I686)

$(PT_BUNDLE_GNULINUX_X86_64): WORKDIR = work/gnulinux-x86_64-$(PT_BUNDLE_VERSION_STRING)
$(PT_BUNDLE_GNULINUX_X86_64): BUNDLE_GNULINUX = $(BUNDLE_GNULINUX_X86_64)

# Shared GNU/Linux 32-bit and 64-bit target.
$(PT_BUNDLE_GNULINUX_I686) $(PT_BUNDLE_GNULINUX_X86_64): TBBDIR = $(WORKDIR)/tor-browser_en-US
$(PT_BUNDLE_GNULINUX_I686) $(PT_BUNDLE_GNULINUX_X86_64):
	# Download and check signature.
	$(MAKE) checksig-$(BUNDLE_GNULINUX)

	rm -rf "$(WORKDIR)"
	mkdir -p "$(WORKDIR)"
	tar zxf "$(BUNDLE_GNULINUX)" -C "$(WORKDIR)"

	cp "$(FLASHPROXY_DIST)"/{flashproxy-client,flashproxy-reg-email,flashproxy-reg-http,flashproxy-reg-url} "$(TBBDIR)"/App
	cp -rL /usr/lib/pymodules/python2.6/M2Crypto "$(TBBDIR)"/App
	mkdir -p "$(TBBDIR)"/Docs/FlashProxy
	cp "$(FLASHPROXY_DIST)"/{doc/*,README,LICENSE,ChangeLog} "$(TBBDIR)"/Docs/FlashProxy
	cp -rL "$(PYOBFSPROXY_DIST)"/{obfsproxy,bin/pyobfsproxy} "$(TBBDIR)"/App
	cp -rL /usr/lib/python2.6/dist-packages/{Crypto,twisted,zope} "$(TBBDIR)"/App
	cp -rL /usr/lib/pymodules/python2.6/argparse.py "$(TBBDIR)"/App
	cp -rL /usr/local/lib/python2.6/dist-packages/pyptlib "$(TBBDIR)"/App
	mkdir -p "$(TBBDIR)"/Docs/PyObfsproxy
	cp "$(PYOBFSPROXY_DIST)"/{LICENSE,README} "$(TBBDIR)"/Docs/PyObfsproxy
	find "$(TBBDIR)"/App -name '*.pyc' | xargs rm -f

	cat "$(FLASHPROXY_HOME)"/doc/bundle-torrc-gnulinux >> "$(TBBDIR)"/Data/Tor/torrc

	tar czf "$@" -C "$(WORKDIR)" tor-browser_en-US

# Download targets.
$(BUNDLE_GNULINUX_I686) $(BUNDLE_GNULINUX_I686).asc \
$(BUNDLE_GNULINUX_X86_64) $(BUNDLE_GNULINUX_X86_64).asc:
	rm -f "$@"
	wget --no-clobber "$(BUNDLE_DIST_URL)/linux/$@"

checksig-%: % %.asc
	gpg --verify "$*".asc "$*"

# Need Bash for certain wildcards.
SHELL = /bin/bash
.PHONY: checksig-% gnulinux-i686 gnulinux-x86_64
