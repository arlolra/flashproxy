.PHONY: prepublish apt-get-build-dep

apt-get-build-dep:
	apt-get install nodejs node-xmlhttprequest
	apt-get install npm && npm install ws
	@echo "warning: Debian has node.js as /usr/bin/nodejs; install nodejs-legacy if you need it in /usr/bin/node"

prepublish: flashproxy.js
flashproxy.js: ../../flashproxy.js
	cp -f $< $@
