# our own variables

fpfacilitatoruser = @fpfacilitatoruser@
initconfdir = @initconfdir@
cgibindir = @cgibindir@

# unfortunately sysvinit does not support having initscripts in /usr/local/etc
# yet, so we have to hard code a path here. :(
initscriptdir = /etc/init.d
exampledir = $(docdir)/examples
appenginedir = $(pkgdatadir)/appengine
pkgconfdir = $(sysconfdir)/flashproxy
appengineconfdir = $(pkgconfdir)/reg-appspot

PYENV = PYTHONPATH='$(srcdir):$(PYTHONPATH)'; export PYTHONPATH;

# automake PLVs

dist_bin_SCRIPTS = fp-facilitator fp-registrar-email fp-reg-decryptd fp-reg-decrypt
man1_MANS = $(dist_bin_SCRIPTS:%=doc/%.1)
dist_cgibin_SCRIPTS = fp-registrar.cgi
if DO_INITSCRIPTS
initscript_names = fp-facilitator fp-registrar-email fp-reg-decryptd
initscript_SCRIPTS = $(initscript_names:%=init.d/%)
dist_initconf_DATA = $(initscript_names:%=default/%)
endif

dist_doc_DATA = doc/appspot-howto.txt doc/facilitator-design.txt doc/email-howto.txt doc/http-howto.txt doc/server-howto.txt README
dist_example_DATA = examples/fp-facilitator.conf examples/reg-email.pass examples/facilitator-relays
pkgconf_DATA = examples/facilitator-relays
dist_appengine_DATA = appengine/app.yaml appengine/config.go appengine/fp-reg.go
appengineconf_DATA = appengine/config.go
CLEANFILES = examples/fp-facilitator.conf $(man1_MANS)
EXTRA_DIST = examples/fp-facilitator.conf.in mkman.sh mkman.inc HACKING $(TESTS)

TESTS = fp-facilitator-test.py
# see http://www.gnu.org/software/automake/manual/html_node/Parallel-Test-Harness.html#index-TEST_005fEXTENSIONS
TEST_EXTENSIONS = .py
PY_LOG_COMPILER = $(PYTHON)
AM_TESTS_ENVIRONMENT = $(PYENV)
AM_PY_LOG_FLAGS =

# AC_CONFIG_FILES doesn't fully-expand directory variables
# see http://www.gnu.org/software/automake/manual/automake.html#Scripts
subst_vars = sed -e 's,[@]cgibindir[@],$(cgibindir),g'

# our own targets

doc/%.1: % mkman.sh mkman.inc Makefile
# mkdir needed for out-of-source build
	$(MKDIR_P) $$(dirname "$@")
	{ $(PYENV) $(PYTHON) "$<" --help; } \
	  | { $(PYENV) $(srcdir)/mkman.sh "$<" $(VERSION) > "$@"; }

examples/fp-facilitator.conf: examples/fp-facilitator.conf.in Makefile
# mkdir needed for out-of-source build
	$(MKDIR_P) $$(dirname "$@")
	$(subst_vars) "$<" > "$@"

pylint: $(dist_bin_SCRIPTS)
	pylint -E $^

install-data-local:
	$(INSTALL_DATA) -m 600 -t $(DESTDIR)$(pkgconfdir) $(srcdir)/examples/reg-email.pass

uninstall-local:
	rm $(DESTDIR)$(pkgconfdir)/reg-email.pass

# The {pre,post}-{install,remove} targets are just given as reference, and
# ought to be separate scripts as part of your distro's installation process.
# They are intentionally not linked to the install target since they require
# root access and *must not be run* for fake/staged installs, e.g. when giving
# non-standard directories to ./configure or DESTDIR to make.

pre-install: meta-install-sanity install-user
post-install: meta-install-sanity install-symlinks install-daemon
pre-remove: meta-install-sanity remove-daemon remove-symlinks
post-remove: meta-install-sanity
pre-purge: pre-remove remove-daemon-data
post-purge: post-remove remove-user

meta-install-sanity:
	test "x$(DESTDIR)" = "x" || { echo >&2 \
	  "don't run {pre,post}-{install,remove} when DESTDIR is set"; false; }

install-user:
	id -u ${fpfacilitatoruser} >/dev/null 2>&1 || { \
	which adduser >/dev/null 2>&1 && \
	  adduser --quiet \
	    --system \
	    --group \
	    --disabled-password \
	    --home ${pkgconfdir} \
	    --no-create-home \
	    --shell /bin/false \
	    ${fpfacilitatoruser} || \
	  useradd \
	    --system \
	    --home ${pkgconfdir} \
	    -M \
	    --shell /bin/false \
	    ${fpfacilitatoruser} ; }

remove-user:
	: # deluser does actually remove the group as well
	id -u ${fpfacilitatoruser} >/dev/null 2>&1 && { \
	which deluser >/dev/null 2>&1 && \
	  deluser --quiet \
	    --system \
	    ${fpfacilitatoruser} || \
	  userdel \
	    ${fpfacilitatoruser} ; } || true

install-symlinks:
	for i in fp-reg.go app.yaml; do \
	  $(LN_S) -f ${appenginedir}/$$i ${appengineconfdir}/$$i; \
	done

remove-symlinks:
	for i in fp-reg.go app.yaml; do \
	  rm -f ${appengineconfdir}/$$i; \
	done

# initscripts: assume that if the user wanted to install them, then they also
# wanted to configure them, and that the system supports them. if this isn't the
# case then either (a) they are doing a staged install for another system and
# shouldn't be running {pre,post}-{install,remove} or (b) they shouldn't have
# told us to install initscripts for their system that doesn't support it.

install-daemon:
if DO_INITSCRIPTS
# initscripts use these directories for logs and runtime data
	mkdir -p ${localstatedir}/log
	mkdir -p ${localstatedir}/run
	for i in ${initscript_names}; do \
	  update-rc.d $$i defaults; \
	  invoke-rc.d $$i start; \
	done
endif

remove-daemon:
if DO_INITSCRIPTS
# we don't rm created directories since they might be system-managed
	for i in ${initscript_names}; do \
	  invoke-rc.d $$i stop; \
	  update-rc.d $$i remove; \
	done
endif

remove-daemon-data:
	for i in reg-daemon.key reg-daemon.pub; do \
	  rm -f ${pkgconfdir}/$$i; \
	done
if DO_INITSCRIPTS
	for i in ${initscript_names}; do \
	  rm -f ${localstatedir}/log/$$i.log* \
	  rm -f ${localstatedir}/run/$$i.pid; \
	done
endif

.PHONY: pre-install post-install pre-remove post-remove pre-purge post-purge
.PHONY: install-user install-symlinks install-daemon
.PHONY: remove-user remove-symlinks remove-daemon
.PHONY: pylint
