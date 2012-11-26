PROGRAMS = websocket-client websocket-server

all: $(PROGRAMS)

websocket-client: websocket-client.go socks.go pt.go
websocket-server: websocket-server.go pt.go

%: %.go
	go build -o $@ $^

clean:
	rm -f $(PROGRAMS)

fmt:
	go fmt

.PHONY: all clean fmt
