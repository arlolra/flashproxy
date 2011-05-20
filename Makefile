MXMLC ?= mxmlc

TARGETS = swfcat.swf com/rtmfpcat/rtmfpcat.swf

all: $(TARGETS)

swfcat.swf: badge.png

%.swf: %.as
	$(MXMLC) -output $@ -static-link-runtime-shared-libraries -define=RTMFP::CIRRUS_KEY,\"$(CIRRUS_KEY)\" $<

clean:
	rm -f $(TARGETS)
