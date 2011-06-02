MXMLC ?= mxmlc

TARGETS = rtmfpcat.swf

all: $(TARGETS)

swfcat.swf: badge.png

%.swf: %.as
	$(MXMLC) -output $@ -static-link-runtime-shared-libraries -define=RTMFP::CIRRUS_KEY,\"$(CIRRUS_KEY)\" $<

clean:
	rm -f $(TARGETS)
