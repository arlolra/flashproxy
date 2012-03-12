PREFIX = /usr/local
BINDIR = $(PREFIX)/bin

MXMLC ?= mxmlc

TARGETS = swfcat.swf

all: $(TARGETS)

swfcat.swf: *.as badge.png

%.swf: %.as
	$(MXMLC) -output $@ -static-link-runtime-shared-libraries $<

install:
	mkdir -p $(BINDIR)
	cp -f connector.py facilitator.py $(BINDIR)

clean:
	rm -f $(TARGETS)

test:
	./flashproxy-test.js

.PHONY: all clean test
