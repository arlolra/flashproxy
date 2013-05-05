all:
	:

test:
	./flashproxy-test.js

LANGS = de en ru
badges: $(addprefix badge-, $(addsuffix .png, $(LANGS))) link

link:
	ln -s badge-en.png badge.png

badge-%.png: badge.xcf
	gimp -i -b '$(shell cat export_badges.scm) (eb "$*") (exit)'

clean:
	rm badge*.png

.PHONY: all test badges link clean
