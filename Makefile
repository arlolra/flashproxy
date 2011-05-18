MXMLC ?= mxmlc

TARGETS = swfcat.swf

all: $(TARGETS)

swfcat.swf: badge.png

%.swf: %.as
	$(MXMLC) -output $@ -static-link-runtime-shared-libraries $<

clean:
	rm -f $(TARGETS)
