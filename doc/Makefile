BUNDLE_VERSION = 2.4.12
BUNDLE_RELEASE = alpha-2
PT_BUNDLE_RELEASE = pt1

PYPTLIB_HOME = $(HOME)/pyptlib
PYPTLIB_WORK = $(WORKDIR)/pyptlib
OBFSPROXY_HOME = $(HOME)/obfsproxy
OBFSPROXY_WORK = $(WORKDIR)/obfsproxy
OBFSPROXY_DIST_WIN32 = $(OBFSPROXY_WORK)/py2exe_bundle/dist
FLASHPROXY_HOME = $(HOME)/flashproxy
FLASHPROXY_WORK = $(WORKDIR)/flashproxy
FLASHPROXY_DISTNAME = flashproxy-client
FLASHPROXY_DIST = $(FLASHPROXY_WORK)/dist/$(FLASHPROXY_DISTNAME)

MACOSX_BUNDLE_ROOT = $(HOME)/bundle

PYTHON = python
P7Z = /cygdrive/c/Program Files (x86)/7-Zip/7z
P7ZG = /cygdrive/c/Program Files (x86)/7-Zip/7zg

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
	@echo $$'\tmake fetch-windows'
	@echo $$'\tmake fetch-macosx-i686'
	@echo $$'\tmake fetch-gnulinux-i686'
	@echo $$'\tmake fetch-gnulinux-x86_64'
	@echo
	@echo $$'\tmake windows'
	@echo $$'\tmake macosx-i686'
	@echo $$'\tmake gnulinux-i686'
	@echo $$'\tmake gnulinux-x86_64'
	@echo
	@echo "Configure version numbers at the top of this makefile."

fetch-windows: checksig-$(BUNDLE_WINDOWS)
fetch-macosx-i686: checksig-$(BUNDLE_MACOSX_I686)
fetch-gnulinux-i686: checksig-$(BUNDLE_GNULINUX_I686)
fetch-gnulinux-x86_64: checksig-$(BUNDLE_GNULINUX_X86_64)

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
$(PT_BUNDLE_WINDOWS): export PYTHONPATH = $(shell cygpath --absolute --windows "$(PYPTLIB_WORK)"/build)
$(PT_BUNDLE_WINDOWS):
	@if [ ! -f "$(BUNDLE_WINDOWS)" ]; then \
		echo "$(BUNDLE_WINDOWS) is missing."; \
		echo "Run \"make fetch-windows\"."; \
		false; \
	fi
	rm -rf "$(WORKDIR)"
	mkdir -p "$(WORKDIR)"
	"$(P7Z)" x -o"$(WORKDIR)" "$(BUNDLE_WINDOWS)"

	git clone "$(PYPTLIB_HOME)" "$(PYPTLIB_WORK)"
	cd "$(PYPTLIB_WORK)" && "$(PYTHON)" setup.py clean --all build --build-lib build

	git clone "$(OBFSPROXY_HOME)" "$(OBFSPROXY_WORK)"
	cd "$(OBFSPROXY_WORK)" && "$(PYTHON)" setup_py2exe.py clean --all py2exe
	cp -Rn "$(OBFSPROXY_DIST_WIN32)"/{*.pyd,*.dll,*.exe,*.zip} "$(TBBDIR)"/App
	mkdir -p "$(TBBDIR)"/Docs/Obfsproxy
	cp "$(OBFSPROXY_WORK)"/{LICENSE,README} "$(TBBDIR)"/Docs/Obfsproxy

	git clone "$(FLASHPROXY_HOME)" "$(FLASHPROXY_WORK)"
	cd "$(FLASHPROXY_WORK)" && "$(MAKE)" clean dist-exe DISTNAME="$(FLASHPROXY_DISTNAME)"
	cp -Rn "$(FLASHPROXY_DIST)"/{*.pyd,*.dll,*.exe,*.zip} "$(TBBDIR)"/App
	mkdir -p "$(TBBDIR)"/Docs/FlashProxy
	cp "$(FLASHPROXY_DIST)"/{doc/*,README,LICENSE,ChangeLog} "$(TBBDIR)"/Docs/FlashProxy

	cat bundle-torrc-windows >> "$(TBBDIR)"/Data/Tor/torrc

	# 7zg (as opposed to 7z) causes the self-extractor to show a GUI.
	cd "$(WORKDIR)" && "$(P7ZG)" a -sfx "$@" "Tor Browser"
	mv "$(WORKDIR)/$@" .

$(PT_BUNDLE_MACOSX_I686): TBBDIR = $(WORKDIR)/TorBrowser_en-US.app
$(PT_BUNDLE_MACOSX_I686):
	@if [ ! -f "$(BUNDLE_MACOSX_I686)" ]; then \
		echo "$(BUNDLE_MACOSX_I686) is missing."; \
		echo "Run \"make fetch-macosx-i686\"."; \
		false; \
	fi
	rm -rf "$(WORKDIR)"
	mkdir -p "$(WORKDIR)"
	unzip "$(BUNDLE_MACOSX_I686)" -d "$(WORKDIR)"

	git clone "$(PYPTLIB_HOME)" "$(PYPTLIB_WORK)"
	cd "$(PYPTLIB_WORK)" && "$(PYTHON)" setup.py clean --all build --build-lib build
	cp -RL "$(PYPTLIB_WORK)"/build/pyptlib "$(TBBDIR)"/Contents/MacOS

	git clone "$(OBFSPROXY_HOME)" "$(OBFSPROXY_WORK)"
	cd "$(OBFSPROXY_WORK)" && "$(PYTHON)" setup.py clean --all build --build-lib build
	cp -RL "$(OBFSPROXY_WORK)"/build/obfsproxy "$(TBBDIR)"/Contents/MacOs
	cp -RL "$(OBFSPROXY_WORK)"/bin/obfsproxy "$(TBBDIR)"/Contents/MacOs/obfsproxy.bin
	mkdir -p "$(TBBDIR)"/Contents/Resources/Docs/Obfsproxy
	cp "$(OBFSPROXY_WORK)"/{LICENSE,README} "$(TBBDIR)"/Contents/Resources/Docs/Obfsproxy
	cp -RL "$(MACOSX_BUNDLE_ROOT)"/usr/lib/python2.7/site-packages/Crypto "$(TBBDIR)"/Contents/MacOS
	cp "$(MACOSX_BUNDLE_ROOT)"/argparse-1.2.1/argparse.py "$(TBBDIR)"/Contents/MacOS

	git clone "$(FLASHPROXY_HOME)" "$(FLASHPROXY_WORK)"
	cd "$(FLASHPROXY_WORK)" && "$(MAKE)" clean dist DISTNAME="$(FLASHPROXY_DISTNAME)"
	cp "$(FLASHPROXY_DIST)"/{flashproxy-client,flashproxy-reg-appspot,flashproxy-reg-email,flashproxy-reg-http,flashproxy-reg-url} "$(TBBDIR)"/Contents/MacOS
	mkdir -p "$(TBBDIR)"/Contents/Resources/Docs/FlashProxy
	cp "$(FLASHPROXY_DIST)"/{doc/*,README,LICENSE,ChangeLog} "$(TBBDIR)"/Contents/Resources/Docs/FlashProxy
	cp -RL "$(MACOSX_BUNDLE_ROOT)"/usr/lib/python2.7/site-packages/M2Crypto "$(TBBDIR)"/Contents/MacOS

	find "$(TBBDIR)"/Contents/MacOS -name '*.pyc' -print0 | xargs -0 rm -f

	cat bundle-torrc-macosx >> "$(TBBDIR)"/Library/Vidalia/torrc

	cd "$(WORKDIR)" && zip -r -9 "$@" TorBrowser_en-US.app/
	mv "$(WORKDIR)/$@" .

# Shared GNU/Linux 32-bit and 64-bit target.
$(PT_BUNDLE_GNULINUX_I686) $(PT_BUNDLE_GNULINUX_X86_64): TBBDIR = $(WORKDIR)/tor-browser_en-US
$(PT_BUNDLE_GNULINUX_I686) $(PT_BUNDLE_GNULINUX_X86_64):
	@if [ ! -f "$(BUNDLE_GNULINUX)" ]; then \
		echo "$(BUNDLE_GNULINUX) is missing."; \
		echo "Run \"make fetch-gnulinux-i686\" or \"make fetch gnulinux-x86_64\"."; \
		false; \
	fi
	rm -rf "$(WORKDIR)"
	mkdir -p "$(WORKDIR)"
	tar zxf "$(BUNDLE_GNULINUX)" -C "$(WORKDIR)"

	git clone "$(PYPTLIB_HOME)" "$(PYPTLIB_WORK)"
	cd "$(PYPTLIB_WORK)" && "$(PYTHON)" setup.py clean --all build --build-lib build
	cp -RL "$(PYPTLIB_WORK)"/build/pyptlib "$(TBBDIR)"/App

	git clone "$(OBFSPROXY_HOME)" "$(OBFSPROXY_WORK)"
	cd "$(OBFSPROXY_WORK)" && "$(PYTHON)" setup.py clean --all build --build-lib build
	cp -RL "$(OBFSPROXY_WORK)"/build/obfsproxy "$(TBBDIR)"/App
	cp -RL "$(OBFSPROXY_WORK)"/bin/obfsproxy "$(TBBDIR)"/App/obfsproxy.bin
	mkdir -p "$(TBBDIR)"/Docs/Obfsproxy
	cp "$(OBFSPROXY_WORK)"/{LICENSE,README} "$(TBBDIR)"/Docs/Obfsproxy
	cp -RL /usr/lib/python2.6/dist-packages/{Crypto,twisted,zope} "$(TBBDIR)"/App
	cp -RL /usr/lib/pymodules/python2.6/argparse.py "$(TBBDIR)"/App

	git clone "$(FLASHPROXY_HOME)" "$(FLASHPROXY_WORK)"
	cd "$(FLASHPROXY_WORK)" && "$(MAKE)" clean dist DISTNAME="$(FLASHPROXY_DISTNAME)"
	cp "$(FLASHPROXY_DIST)"/{flashproxy-client,flashproxy-reg-appspot,flashproxy-reg-email,flashproxy-reg-http,flashproxy-reg-url} "$(TBBDIR)"/App
	mkdir -p "$(TBBDIR)"/Docs/FlashProxy
	cp "$(FLASHPROXY_DIST)"/{doc/*,README,LICENSE,ChangeLog} "$(TBBDIR)"/Docs/FlashProxy
	cp -RL /usr/lib/pymodules/python2.6/M2Crypto "$(TBBDIR)"/App

	find "$(TBBDIR)"/App -name '*.pyc' -print0 | xargs -0 rm -f

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

clean:
	rm -rf "$(WORKDIR)"
	rm -rf "$(PT_BUNDLE_WINDOWS)"
	rm -rf "$(PT_BUNDLE_MACOSX_I686)"
	rm -rf "$(PT_BUNDLE_GNULINUX_I686)"
	rm -rf "$(PT_BUNDLE_GNULINUX_X86_64)"

# Need Bash for certain wildcards.
SHELL = /bin/bash
.PHONY: clean checksig-% windows macosx-i686 gnulinux-i686 gnulinux-x86_64
