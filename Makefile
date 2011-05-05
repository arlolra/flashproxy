MXMLC ?= mxmlc

TARGETS = swfcat.swf Proxy.swf

all: $(TARGETS)

%.swf: %.as
	$(MXMLC) -output $@ -define=RTMFP::CIRRUS_KEY,\"$(CIRRUS_KEY)\" $^

clean:
	rm -f $(TARGETS)
