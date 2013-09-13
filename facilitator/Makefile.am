# our own variables

fpfacilitatoruser = @fpfacilitatoruser@
initscriptdir = $(sysconfdir)/init.d
exampledir = $(docdir)/examples
appenginedir = $(pkgdatadir)/appengine

# automake PLVs

dist_bin_SCRIPTS = facilitator facilitator-email-poller facilitator-reg-daemon facilitator-reg facilitator.cgi fac.py
initscript_SCRIPTS = init.d/facilitator init.d/facilitator-email-poller init.d/facilitator-reg-daemon

dist_doc_DATA = doc/appengine-howto.txt doc/facilitator-howto.txt doc/gmail-howto.txt README
dist_example_DATA = conf/fp-facilitator
dist_appengine_DATA = appengine/app.yaml appengine/config.go appengine/fp-reg.go appengine/README

dist_TESTS = facilitator-test

# stuff built from AC_CONFIG_FILES
# see http://www.gnu.org/software/automake/manual/html_node/Scripts.html
CLEANFILES = $(initscript_SCRIPTS)

# our own targets

# The {pre,post}-{install,remove} targets are just given as reference, and
# ought to be separate scripts as part of your distro's installation process.
# They are intentionally not linked to the install target since they require
# root access and *must not be run* for fake/staged installs, e.g. when giving
# non-standard directories to ./configure or DESTDIR to make.

pre-install:
	id -u $(fpfacilitatoruser) >/dev/null 2>&1 || { \
	which adduser >/dev/null 2>&1 && \
	  adduser --quiet \
	    --system \
	    --disabled-password \
	    --home $(sysconfdir)/flashproxy \
	    --no-create-home \
	    --shell /bin/false \
	    $(fpfacilitatoruser) || \
	  useradd \
	    --system \
	    --home $(sysconfdir)/flashproxy \
	    -M \
	    --shell /bin/false \
	    $(fpfacilitatoruser) ; }

post-install:
	for i in facilitator facilitator-email-poller facilitator-reg-daemon; do \
	  update-rc.d $$i defaults; \
	  invoke-rc.d $$i start; \
	done

pre-remove:
	for i in facilitator facilitator-email-poller facilitator-reg-daemon; do \
	  invoke-rc.d $$i stop; \
	done

post-remove:
	id -u $(fpfacilitatoruser) >/dev/null 2>&1 && { \
	which deluser >/dev/null 2>&1 && \
	  deluser --quiet \
	    --system \
	    $(fpfacilitatoruser) || \
	  userdel \
	    $(fpfacilitatoruser) ; }

.PHONY: pre-install post-install pre-remove post-remove
