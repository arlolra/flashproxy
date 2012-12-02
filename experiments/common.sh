# This file contains common variables and subroutines used by the experiment
# scripts.

FLASHPROXY_DIR="$(dirname $BASH_SOURCE)/.."

FIREFOX=firefox
SOCAT=socat
WEBSOCKIFY=websockify
THTTPD=thttpd
TOR=tor

visible_sleep() {
	N="$1"
	echo -n "sleep $N"
	while [ "$N" -gt 0 ]; do
		sleep 1
		N=$((N-1))
		echo -ne "\rsleep $N "
	done
	echo -ne "\n"
}

ensure_browser_started() {
	local PROFILE="$1"
	("$FIREFOX" -P "$PROFILE" -remote "ping()" || ("$FIREFOX" -P "$PROFILE" -no-remote & visible_sleep 5)) 2>/dev/null
}

browser_clear() {
	local PROFILE="$1"
	("$FIREFOX" -P "$PROFILE" -remote "ping()" && "$FIREFOX" -P "$PROFILE" -remote "openurl(about:blank)" &) 2>/dev/null
}

browser_goto() {
	local PROFILE="$1"
	local URL="$2"
	ensure_browser_started "$PROFILE"
	"$FIREFOX" -P "$PROFILE" -remote "openurl($URL)" 2>/dev/null
}

# Run a command and get the "real" part of time(1) output as a number of
# seconds.
real_time() {
	# Make a spare copy of stderr (fd 2).
	exec 3>&2
	# Point the subcommand's stderr to our copy (fd 3), and extract the
	# original stderr (fd 2) output of time.
	(time -p eval "$@" 2>&3) |& tail -n 3 | head -n 1 | awk '{print $2}'
}

# Repeat a subcommand N times.
repeat() {
	local N
	N="$1"
	shift
	while [ $N -gt 0 ]; do
		eval "$@"
		N=$((N-1))
	done
}
