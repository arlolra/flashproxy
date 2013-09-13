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
AC_OUTPUT
