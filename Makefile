MXMLC ?= mxmlc

TARGETS = rtmfpcat.swf return_of_the_rtmfpcat.swf

all: $(TARGETS)

swfcat.swf: badge.png

%.swf: %.as
	$(MXMLC) -output $@ -static-link-runtime-shared-libraries -define=RTMFP::CIRRUS_KEY,\"$(CIRRUS_KEY)\" $<

clean:
	rm -f $(TARGETS)
