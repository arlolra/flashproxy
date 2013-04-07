BUNDLE_VERSION = 2.4.11
BUNDLE_RELEASE = alpha-2
PT_BUNDLE_RELEASE = pt1

FLASHPROXY_HOME = $(HOME)/flashproxy
FLASHPROXY_VERSION = 1.0
FLASHPROXY_DIST = $(FLASHPROXY_HOME)/dist/flashproxy-client-$(FLASHPROXY_VERSION)
FLASHPROXY_DIST_WIN32 = $(FLASHPROXY_HOME)/dist/flashproxy-client-$(FLASHPROXY_VERSION)-win32
PYOBFSPROXY_HOME = $(HOME)/pyobfsproxy
PYOBFSPROXY_DIST = $(PYOBFSPROXY_HOME)
PYOBFSPROXY_DIST_WIN32 = $(PYOBFSPROXY_HOME)/py2exe_bundle/dist
MACOSX_BUNDLE_ROOT = $(HOME)/bundle

P7Z = /cygdrive/c/Program Files (x86)/7-Zip/7z
P7ZG = /cygdrive/c/Program Files (x86)/7-Zip/7zg

DOWNLOADDIR = download
WORKDIR = work

BUNDLE_DIST_URL = https://www.torproject.org/dist/torbrowser

BUNDLE_VERSION_STRING = $(BUNDLE_VERSION)-$(BUNDLE_RELEASE)
PT_BUNDLE_VERSION_STRING = $(BUNDLE_VERSION)-$(BUNDLE_RELEASE)-$(PT_BUNDLE_RELEASE)

BUNDLE_WINDOWS = tor-browser-$(BUNDLE_VERSION_STRING)_en-US.exe
BUNDLE_MACOSX_I686 = TorBrowser-$(BUNDLE_VERSION_STRING)-osx-i386-en-US.zip
BUNDLE_GNULINUX_I686 = tor-browser-gnu-linux-i686-$(BUNDLE_VERSION_STRING)-dev-en-US.tar.gz
BUNDLE_GNULINUX_X86_64 = tor-browser-gnu-linux-x86_64-$(BUNDLE_VERSION_STRING)-dev-en-US.tar.gz

PT_BUNDLE_WINDOWS = tor-pluggable-transports-browser-$(PT_BUNDLE_VERSION_STRING)_en-US.exe
PT_BUNDLE_MACOSX_I686 = TorBrowser-Pluggable-Transports-$(BUNDLE_VERSION_STRING)-osx-i386-en-US.zip
PT_BUNDLE_GNULINUX_I686 = tor-pluggable-transports-browser-gnu-linux-i686-$(PT_BUNDLE_VERSION_STRING)-dev-en-US.tar.gz
PT_BUNDLE_GNULINUX_X86_64 = tor-pluggable-transports-browser-gnu-linux-x86_64-$(PT_BUNDLE_VERSION_STRING)-dev-en-US.tar.gz

all:
	@echo "Try one of these:"
	@echo $$'\tmake windows'
	@echo $$'\tmake macosx-i686'
	@echo $$'\tmake gnulinux-i686'
	@echo $$'\tmake gnulinux-x86_64'
	@echo
	@echo "Configure version numbers at the top of this makefile."
	@echo "Before starting, you need to run:"
	@echo $$'\t"make dist" in the flashproxy directory'
	@echo "Or on Windows:"
	@echo $$'\t"make dist-exe" in the flashproxy directory'
	@echo $$'\t"python setup_py2exe.py py2exe" in the pyobfsproxy directory'

windows: $(PT_BUNDLE_WINDOWS)
macosx-i686: $(PT_BUNDLE_MACOSX_I686)
gnulinux-i686: $(PT_BUNDLE_GNULINUX_I686)
gnulinux-x86_64: $(PT_BUNDLE_GNULINUX_X86_64)

$(PT_BUNDLE_WINDOWS): WORKDIR = work/windows-$(PT_BUNDLE_VERSION_STRING)

$(PT_BUNDLE_MACOSX_I686): WORKDIR = work/macosx-$(PT_BUNDLE_VERSION_STRING)

$(PT_BUNDLE_GNULINUX_I686): WORKDIR = work/gnulinux-i686-$(PT_BUNDLE_VERSION_STRING)
$(PT_BUNDLE_GNULINUX_I686): BUNDLE_GNULINUX = $(BUNDLE_GNULINUX_I686)

$(PT_BUNDLE_GNULINUX_X86_64): WORKDIR = work/gnulinux-x86_64-$(PT_BUNDLE_VERSION_STRING)
$(PT_BUNDLE_GNULINUX_X86_64): BUNDLE_GNULINUX = $(BUNDLE_GNULINUX_X86_64)

$(PT_BUNDLE_WINDOWS): TBBDIR = $(WORKDIR)/Tor Browser
$(PT_BUNDLE_WINDOWS):
	# Download and check signature.
	$(MAKE) checksig-$(BUNDLE_WINDOWS)

	rm -rf "$(WORKDIR)"
	mkdir -p "$(WORKDIR)"
	"$(P7Z)" x -o"$(WORKDIR)" "$(BUNDLE_WINDOWS)"

	cp -nr "$(FLASHPROXY_DIST_WIN32)"/{*.pyd,*.dll,*.exe,*.zip} "$(TBBDIR)"/App
	mkdir -p "$(TBBDIR)"/Docs/FlashProxy
	cp "$(FLASHPROXY_DIST_WIN32)"/{doc/*,README,LICENSE,ChangeLog} "$(TBBDIR)"/Docs/FlashProxy
	cp -nr "$(PYOBFSPROXY_DIST_WIN32)"/{*.pyd,*.dll,*.exe,*.zip} "$(TBBDIR)"/App
	mkdir -p "$(TBBDIR)"/Docs/PyObfsproxy
	cp "$(PYOBFSPROXY_DIST)"/{LICENSE,README} "$(TBBDIR)"/Docs/PyObfsproxy

	cat bundle-torrc-windows >> "$(TBBDIR)"/Data/Tor/torrc

	# 7zg (as opposed to 7z) causes the self-extractor to show a GUI.
	cd "$(WORKDIR)" && "$(P7ZG)" a -sfx "$@" "Tor Browser"
	mv "$(WORKDIR)/$@" .

$(PT_BUNDLE_MACOSX_I686): TBBDIR = $(WORKDIR)/TorBrowser_en-US.app
$(PT_BUNDLE_MACOSX_I686):
	# Download and check signature.
	$(MAKE) checksig-$(BUNDLE_MACOSX_I686)

	rm -rf "$(WORKDIR)"
	mkdir -p "$(WORKDIR)"
	unzip "$(BUNDLE_MACOSX_I686)" -d "$(WORKDIR)"

	cp "$(FLASHPROXY_DIST)"/{flashproxy-client,flashproxy-reg-email,flashproxy-reg-http,flashproxy-reg-url} "$(TBBDIR)"/Contents/MacOS
	cp -r "$(MACOSX_BUNDLE_ROOT)"/usr/lib/python2.7/site-packages/M2Crypto "$(TBBDIR)"/Contents/MacOS
	mkdir -p "$(TBBDIR)"/Contents/Resources/Docs/FlashProxy
	cp "$(FLASHPROXY_DIST)"/{doc/*,README,LICENSE,ChangeLog} "$(TBBDIR)"/Contents/Resources/Docs/FlashProxy
	cp -r "$(PYOBFSPROXY_DIST)"/{obfsproxy,bin/pyobfsproxy} "$(TBBDIR)"/Contents/MacOs
	cp -r "$(MACOSX_BUNDLE_ROOT)"/usr/lib/python2.7/site-packages/{Crypto,pyptlib} "$(TBBDIR)"/Contents/MacOS
	cp "$(MACOSX_BUNDLE_ROOT)"/argparse-1.2.1/argparse.py "$(TBBDIR)"/Contents/MacOS
	mkdir -p "$(TBBDIR)"/Contents/Resources/Docs/PyObfsproxy
	cp "$(PYOBFSPROXY_DIST)"/{LICENSE,README} "$(TBBDIR)"/Contents/Resources/Docs/PyObfsproxy
	find "$(TBBDIR)"/Contents/MacOS -name '*.pyc' | xargs rm -f

	cat bundle-torrc-macosx >> "$(TBBDIR)"/Library/Vidalia/torrc

	cd "$(WORKDIR)" && zip -r -9 "$@" TorBrowser_en-US.app/
	mv "$(WORKDIR)/$@" .

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

	cat bundle-torrc-gnulinux >> "$(TBBDIR)"/Data/Tor/torrc

	tar czf "$@" -C "$(WORKDIR)" tor-browser_en-US

# Download targets.
$(BUNDLE_WINDOWS) $(BUNDLE_WINDOWS).asc:
	rm -f "$@"
	wget --no-clobber "$(BUNDLE_DIST_URL)/$@"
$(BUNDLE_MACOSX_I686) $(BUNDLE_MACOSX_I686).asc:
	rm -f "$@"
	curl -O "$(BUNDLE_DIST_URL)/osx/$@"
$(BUNDLE_GNULINUX_I686) $(BUNDLE_GNULINUX_I686).asc \
$(BUNDLE_GNULINUX_X86_64) $(BUNDLE_GNULINUX_X86_64).asc:
	rm -f "$@"
	wget --no-clobber "$(BUNDLE_DIST_URL)/linux/$@"

checksig-%: % %.asc
	gpg --verify "$*".asc "$*"

# Need Bash for certain wildcards.
SHELL = /bin/bash
.PHONY: checksig-% windows macosx-i686 gnulinux-i686 gnulinux-x86_64
