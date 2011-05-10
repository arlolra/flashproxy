MXMLC ?= mxmlc

TARGETS = swfcat.swf com/rtmfpcat/rtmfpcat.swf

all: $(TARGETS)

%.swf: %.as
	$(MXMLC) -output $@ -define=RTMFP::CIRRUS_KEY,\"$(CIRRUS_KEY)\" $^

clean:
	rm -f $(TARGETS)
