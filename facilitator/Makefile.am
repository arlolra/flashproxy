# our own variables

fpfacilitatoruser = @fpfacilitatoruser@
initscriptdir = $(sysconfdir)/init.d
exampledir = $(docdir)/examples

# automake PLVs

dist_bin_SCRIPTS = facilitator facilitator-email-poller facilitator-reg-daemon facilitator-reg facilitator.cgi fac.py
initscript_SCRIPTS = init.d/facilitator init.d/facilitator-email-poller init.d/facilitator-reg-daemon

dist_doc_DATA = doc/appengine-howto.txt doc/facilitator-howto.txt doc/gmail-howto.txt README
dist_example_DATA = conf/fp-facilitator

dist_TESTS = facilitator-test

# stuff built from AC_CONFIG_FILES
# see http://www.gnu.org/software/automake/manual/html_node/Scripts.html
CLEANFILES = $(initscript_SCRIPTS)

# our own targets

post-install:
	which adduser >/dev/null 2>&1 && \
	  adduser --quiet \
	    --system \
	    --disabled-password \
	    --home $(sysconfdir)/flashproxy \
	    --no-create-home \
	    --shell /bin/false \
	    --group \
	    $(fpfacilitatoruser) || \
	  useradd \
	    --system \
	    --home $(sysconfdir)/flashproxy \
	    -M \
	    --shell /bin/false \
	    $(fpfacilitatoruser)
	for i in facilitator facilitator-email-poller facilitator-reg-daemon; do \
	  update-rc.d $$i defaults; \
	  /etc/init.d/$$i start; \
	done
