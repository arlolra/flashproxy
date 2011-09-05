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
	cp -f connector.py crossdomaind.py facilitator.py $(BINDIR)

clean:
	rm -f $(TARGETS)

.PHONY: all clean
