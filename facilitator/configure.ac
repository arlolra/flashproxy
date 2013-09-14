AC_PREREQ([2.69])
AC_INIT([flashproxy-facilitator], [1.3])
AM_INIT_AUTOMAKE([-Wall -Werror foreign])

AC_ARG_VAR(fpfacilitatoruser, [the user/group for the facilitator to run as])
fpfacilitatoruser="${fpfacilitatoruser:-flashproxy-fac}"

AC_CONFIG_FILES([Makefile
	init.d/facilitator
	init.d/facilitator-email-poller
	init.d/facilitator-reg-daemon])

AC_PROG_LN_S
# check that we want to install initscripts. don't bother checking that they
# are supported, since we might be doing a staged install on a different system.
AC_ARG_ENABLE([initscripts],
	[AS_HELP_STRING([--disable-initscripts],
		[install and configure sysvinit-style initscripts (default yes)])],
	[do_initscripts=], [do_initscripts=yes])
AM_CONDITIONAL([DO_INITSCRIPTS], [test "x$do_initscripts" = xyes])

AC_OUTPUT
