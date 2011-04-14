MXMLC ?= mxmlc

TARGETS = swfcat.swf

all: $(TARGETS)

%.swf: %.as
	$(MXMLC) -output $@ $^

clean:
	rm -f $(TARGETS)
