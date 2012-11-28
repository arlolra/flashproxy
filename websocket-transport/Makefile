PREFIX = /usr/local
BINDIR = $(PREFIX)/bin

PROGRAMS = websocket-client websocket-server

GOBUILDFLAGS =

all: websocket-server

websocket-client: websocket-client.go socks.go pt.go
websocket-server: websocket-server.go pt.go websocket.go

%: %.go
	go build $(GOBUILDFLAGS) -o $@ $^

install:
	mkdir -p $(BINDIR)
	cp -f websocket-server $(BINDIR)

clean:
	rm -f $(PROGRAMS)

fmt:
	go fmt

.PHONY: all install clean fmt
