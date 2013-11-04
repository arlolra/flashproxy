# our own variables

fpfacilitatoruser = @fpfacilitatoruser@
initconfdir = @initconfdir@

# unfortunately sysvinit does not support having initscripts in /usr/local/etc
# yet, so we have to hard code a path here. :(
initscriptdir = /etc/init.d
exampledir = $(docdir)/examples
appenginedir = $(pkgdatadir)/appengine
pkgconfdir = $(sysconfdir)/flashproxy
appengineconfdir = $(pkgconfdir)/reg-appengine

# automake PLVs

dist_bin_SCRIPTS = facilitator facilitator-email-poller facilitator-reg-daemon facilitator-reg facilitator.cgi fac.py
if DO_INITSCRIPTS
initscript_SCRIPTS = init.d/facilitator init.d/facilitator-email-poller init.d/facilitator-reg-daemon
dist_initconf_DATA = default/facilitator default/facilitator-email-poller default/facilitator-reg-daemon
endif

dist_doc_DATA = doc/appengine-howto.txt doc/facilitator-howto.txt doc/gmail-howto.txt README
dist_example_DATA = examples/fp-facilitator
dist_appengine_DATA = appengine/app.yaml appengine/config.go appengine/fp-reg.go appengine/README
appengineconf_DATA = appengine/config.go

TESTS = facilitator-test.py
# see http://www.gnu.org/software/automake/manual/html_node/Parallel-Test-Harness.html#index-TEST_005fEXTENSIONS
TEST_EXTENSIONS = .py
PY_LOG_COMPILER = $(PYTHON)
AM_TESTS_ENVIRONMENT = PYTHONPATH='$(srcdir)'; export PYTHONPATH;
AM_PY_LOG_FLAGS =

EXTRA_DIST = $(TESTS)

# our own targets

# The {pre,post}-{install,remove} targets are just given as reference, and
# ought to be separate scripts as part of your distro's installation process.
# They are intentionally not linked to the install target since they require
# root access and *must not be run* for fake/staged installs, e.g. when giving
# non-standard directories to ./configure or DESTDIR to make.

pre-install: meta-install-sanity install-user
post-install: meta-install-sanity install-secrets install-symlinks install-daemon
pre-remove: meta-install-sanity remove-daemon remove-symlinks
post-remove: meta-install-sanity
pre-purge: pre-remove remove-secrets
post-purge: post-remove remove-user

meta-install-sanity:
	test "x$(DESTDIR)" = "x" || { echo >&2 \
	  "don't run {pre,post}-{install,remove} when DESTDIR is set"; false; }

install-user:
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

remove-user:
	: # deluser does actually remove the group as well
	id -u $(fpfacilitatoruser) >/dev/null 2>&1 && { \
	which deluser >/dev/null 2>&1 && \
	  deluser --quiet \
	    --system \
	    $(fpfacilitatoruser) || \
	  userdel \
	    $(fpfacilitatoruser) ; } || true

install-secrets:
	test -f $(pkgconfdir)/reg-daemon.key || { \
	  install -m 600 /dev/null $(pkgconfdir)/reg-daemon.key && \
	  openssl genrsa 2048 | tee $(pkgconfdir)/reg-daemon.key | \
	  openssl rsa -pubout > $(pkgconfdir)/reg-daemon.pub; }
	test -f $(pkgconfdir)/reg-email.pass || { \
	  install -m 600 /dev/null $(pkgconfdir)/reg-email.pass && \
	  echo >> $(pkgconfdir)/reg-email.pass \
	  "Replace this file's contents with your Gmail app-specific password;" && \
	  echo >> $(pkgconfdir)/reg-email.pass \
	  "see gmail-howto.txt in this package's documentation for details."; }

remove-secrets:
	rm -f $(pkgconfdir)/reg-*

install-symlinks:
	for i in fp-reg.go app.yaml README; do \
	  $(LN_S) -f $(appenginedir)/$$i $(appengineconfdir)/$$i; \
	done

remove-symlinks:
	rm -rf $(appengineconfdir)

# initscripts: assume that if the user wanted to install them, then they also
# wanted to configure them, and that the system supports them. if this isn't the
# case then either (a) they are doing a staged install for another system and
# shouldn't be running {pre,post}-{install,remove} or (b) they shouldn't have
# told us to install initscripts for their system that doesn't support it.

install-daemon:
if DO_INITSCRIPTS
	for i in facilitator facilitator-email-poller facilitator-reg-daemon; do \
	  update-rc.d $$i defaults; \
	  invoke-rc.d $$i start; \
	done
endif

remove-daemon:
if DO_INITSCRIPTS
	for i in facilitator facilitator-email-poller facilitator-reg-daemon; do \
	  invoke-rc.d $$i stop; \
	  update-rc.d $$i remove; \
	done
endif

.PHONY: pre-install post-install pre-remove post-remove pre-purge post-purge
.PHONY: install-user install-secrets install-symlinks install-daemon
.PHONY: remove-user remove-secrets remove-symlinks remove-daemon
