LANGS = de en pt ru

all: $(addprefix badge-, $(addsuffix .png, $(LANGS)))

test:
	./flashproxy-test.js

badge-%.png: badge.xcf
	(cat badge-export-lang.scm; echo '(export "$*") (gimp-quit 0)') | gimp -i -b -

.PHONY: all test
