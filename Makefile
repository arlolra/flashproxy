MXMLC ?= mxmlc

TARGETS = swfcat.swf

all: $(TARGETS)

%.swf: %.as badge.png
	$(MXMLC) -output $@ -static-link-runtime-shared-libraries -define=RTMFP::CIRRUS_KEY,\"$(CIRRUS_KEY)\" $<

clean:
	rm -f $(TARGETS)
