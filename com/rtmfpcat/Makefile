MXMLC ?= mxmlc

TARGETS = rtmfpcat.swf

all: $(TARGETS)

%.swf: %.as
	$(MXMLC) -output $@ $^

clean:
	rm -f $(TARGETS)
