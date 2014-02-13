.PHONY: all prepublish
topsrcdir = ../../..

ALL_DST = flashproxy.js flashproxy.1
VERSION = $(shell sed -ne 's/^[[:space:]]*"version"[[:space:]]*:[[:space:]]*"\([^"][^"]*\)".*/\1/gp' package.json)

all: $(ALL_DST)

prepublish: flashproxy.js
flashproxy.js: $(topsrcdir)/proxy/flashproxy.js
	cp -f $< $@

flashproxy.1: main.js flashproxy.js $(topsrcdir)/mkman.sh $(topsrcdir)/mkman.inc Makefile
	./main.js --help \
	  | sed -re 's,/\S+/nodejs ./main.js,flashproxy,g' \
	  | $(topsrcdir)/mkman.sh flashproxy "$(VERSION)" "The flashproxy standalone nodejs proxy" "$(VERSION)" > "$@"

clean:
	rm -f $(ALL_DST)
