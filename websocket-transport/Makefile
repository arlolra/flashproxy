PREFIX = /usr/local
BINDIR = $(PREFIX)/bin

PROGRAMS = websocket-client websocket-server

GOBUILDFLAGS =
# Alternate flags to use gccgo, allowing cross-compiling for x86 from
# x86_64, and presumably better optimization. Install this package:
#   apt-get install gccgo-multilib
# GOBUILDFLAGS = -compiler gccgo -gccgoflags "-O3 -m32 -static-libgo"

all: websocket-server

websocket-client: websocket-client.go socks.go
websocket-server: websocket-server.go websocket.go

%: %.go
	go build $(GOBUILDFLAGS) -o $@ $^

install:
	mkdir -p "$(BINDIR)"
	cp -f websocket-server "$(BINDIR)"

clean:
	rm -f $(PROGRAMS)

fmt:
	go fmt

.PHONY: all install clean fmt
