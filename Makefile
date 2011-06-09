MXMLC ?= mxmlc

TARGETS = swfcat.swf

all: $(TARGETS)

%.swf: %.as
	$(MXMLC) -output $@ -static-link-runtime-shared-libraries -define=RTMFP::CIRRUS_KEY,\"$(CIRRUS_KEY)\" $<

swfcat.swf: *.as badge.png

clean:
	rm -f $(TARGETS)
