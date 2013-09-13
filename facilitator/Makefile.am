# our own variables

fpfacilitatoruser = @fpfacilitatoruser@
initscriptdir = $(sysconfdir)/init.d
exampledir = $(docdir)/examples
appenginedir = $(pkgdatadir)/appengine
pkgconfdir = $(sysconfdir)/flashproxy
appengineconfdir = $(pkgconfdir)/reg-appengine

# automake PLVs

dist_bin_SCRIPTS = facilitator facilitator-email-poller facilitator-reg-daemon facilitator-reg facilitator.cgi fac.py
initscript_SCRIPTS = init.d/facilitator init.d/facilitator-email-poller init.d/facilitator-reg-daemon

dist_doc_DATA = doc/appengine-howto.txt doc/facilitator-howto.txt doc/gmail-howto.txt README
dist_example_DATA = examples/fp-facilitator conf/reg-email.pass
dist_appengine_DATA = appengine/app.yaml appengine/config.go appengine/fp-reg.go appengine/README
appengineconf_DATA = appengine/config.go

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
	    --group \
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

post-install-secrets:
	install -m 600 /dev/null $(pkgconfdir)/reg-daemon.key
	openssl genrsa 2048 | tee $(pkgconfdir)/reg-daemon.key | \
	openssl rsa -pubout > $(pkgconfdir)/reg-daemon.pub
	install -m 600 $(exampledir)/reg-email.pass $(pkgconfdir)/reg-email.pass
	chown $(fpfacilitatoruser): $(pkgconfdir)/reg-daemon.key
	chown $(fpfacilitatoruser): $(pkgconfdir)/reg-email.pass

post-install-symlinks:
	for i in fp-reg.go app.yaml README; do \
	  $(LN_S) -f $(appenginedir)/$$i $(appengineconfdir)/$$i; \
	done

post-install-daemon:
	for i in facilitator facilitator-email-poller facilitator-reg-daemon; do \
	  update-rc.d $$i defaults; \
	  invoke-rc.d $$i start; \
	done

post-install: post-install-secrets post-install-symlinks post-install-daemon

pre-remove-daemon:
	for i in facilitator facilitator-email-poller facilitator-reg-daemon; do \
	  invoke-rc.d $$i stop; \
	done

pre-remove-symlinks:
	rm -rf $(appengineconfdir)

pre-remove-secrets:
	rm -f $(pkgconfdir)/reg-*

pre-remove: pre-remove-daemon pre-remove-symlinks pre-remove-secrets

post-remove:
	: # deluser does actually remove the group as well
	id -u $(fpfacilitatoruser) >/dev/null 2>&1 && { \
	which deluser >/dev/null 2>&1 && \
	  deluser --quiet \
	    --system \
	    $(fpfacilitatoruser) || \
	  userdel \
	    $(fpfacilitatoruser) ; } || true

.PHONY: pre-install post-install pre-remove post-remove
.PHONY: post-install-secrets post-install-symlinks post-install-daemon
.PHONY: pre-remove-daemon pre-remove-symlinks pre-remove-secrets
