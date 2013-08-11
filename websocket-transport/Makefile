PREFIX = /usr/local
BINDIR = $(PREFIX)/bin

PROGRAMS = websocket-client websocket-server

export GOPATH = $(CURDIR)
GOBUILDFLAGS =
# Alternate flags to use gccgo, allowing cross-compiling for x86 from
# x86_64, and presumably better optimization. Install this package:
#   apt-get install gccgo-multilib
# GOBUILDFLAGS = -compiler gccgo -gccgoflags "-O3 -m32 -static-libgo"

all: websocket-server

%: $(GOPATH)/src/%/*.go
	go build $(GOBUILDFLAGS) "$*"

# websocket-client has a special rule because "go get" is necessary.
websocket-client: $(GOPATH)/src/websocket-client/*.go
	go get -d $(GOBUILDFLAGS) websocket-client
	go build $(GOBUILDFLAGS) websocket-client

install:
	mkdir -p "$(BINDIR)"
	cp -f websocket-server "$(BINDIR)"

clean:
	rm -f $(PROGRAMS)

fmt:
	go fmt $$(basename -a src/*)

.PHONY: all install clean fmt
