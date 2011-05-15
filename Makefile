MXMLC ?= mxmlc

TARGETS = swfcat.swf

all: $(TARGETS)

swfcat.swf: badge.png

%.swf: %.as
	$(MXMLC) -output $@ $<

clean:
	rm -f $(TARGETS)
