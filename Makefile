MXMLC ?= mxmlc

TARGETS = swfcat.swf

all: $(TARGETS)

swfcat.swf: *.as badge.png

%.swf: %.as
	$(MXMLC) -output $@ -static-link-runtime-shared-libraries -define=RTMFP::CIRRUS_KEY,\"$(CIRRUS_KEY)\" $<

clean:
	rm -f $(TARGETS)
