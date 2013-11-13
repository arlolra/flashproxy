AC_PREREQ([2.68])
AC_INIT([flashproxy-facilitator], [1.3])
AM_INIT_AUTOMAKE([-Wall -Werror foreign])

AC_ARG_VAR(fpfacilitatoruser, [the user/group for the facilitator to run as])
fpfacilitatoruser="${fpfacilitatoruser:-fp-facilitator}"

# check that we want to install initscripts. don't bother checking that they
# are supported, since we might be doing a staged install on a different system.
# disabled by default since it ignores ${prefix} so `make distcheck` would fail
AC_ARG_ENABLE([initscripts],
	[AS_HELP_STRING([--enable-initscripts],
		[install and configure sysvinit-style initscripts (default no)])],
	[do_initscripts=yes], [do_initscripts=])
AM_CONDITIONAL([DO_INITSCRIPTS], [test "x$do_initscripts" = xyes])

AC_ARG_VAR(initconfdir, [directory for initscripts configuration, if enabled])
# Try to detect the appropriate conf dir. Several systems have both /etc/default
# and /etc/sysconfig but latter is always primary.
if test "x$do_initscripts" = xyes; then
if test "x$initconfdir" = x; then
AC_CHECK_FILE(/etc/conf.d, [initconfdir='$(sysconfdir)/conf.d}'], [# Gentoo/Arch
AC_CHECK_FILE(/etc/sysconfig, [initconfdir='$(sysconfdir)/sysconfig'], [# RedHat/Fedora/Slax/Mandriva/SuSE
AC_CHECK_FILE(/etc/default, [initconfdir='$(sysconfdir)/default'], [# Debian/Ubuntu
AC_MSG_ERROR([could not determine system initscripts config dir; please set initconfdir manually.])])])])
fi
fi

# Try to detect cgi-bin directory, falling back to $(libexec) if not found
# from http://wiki.apache.org/httpd/DistrosDefaultLayout
AC_ARG_VAR(cgibindir, [directory for CGI executables])
if test "x$cgibindir" = x; then
AC_CHECK_FILE(/usr/lib/cgi-bin, [cgibindir='$(libdir)/cgi-bin'], [
AC_CHECK_FILE(/var/www/cgi-bin, [cgibindir='/var/www/cgi-bin'], [
AC_CHECK_FILE(/srv/httpd/cgi-bin, [cgibindir='/srv/httpd/cgi-bin'], [
AC_MSG_WARN([could not determine system CGI executables dir, using \$(libexecdir); set cgibindir to override.])
cgibindir='$(libexecdir)'
])])])
fi

AC_PROG_LN_S
AM_PATH_PYTHON

AC_CONFIG_FILES([Makefile
	init.d/facilitator
	init.d/facilitator-email-poller
	init.d/facilitator-reg-daemon])

AC_OUTPUT
