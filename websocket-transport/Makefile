PROGRAMS = websocket-client

all: $(PROGRAMS)

websocket-client: websocket-client.go socks.go pt.go

%: %.go
	go build -o $@ $^

clean:
	rm -f $(PROGRAMS)

fmt:
	go fmt

.PHONY: all clean fmt
