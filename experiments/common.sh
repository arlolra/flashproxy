# This file contains common variables and subroutines used by the experiment
# scripts.

FLASHPROXY_DIR="$(dirname $BASH_SOURCE)/.."

FIREFOX=firefox
SOCAT=socat
THTTPD=thttpd
TOR=tor

visible_sleep() {
	N="$1"
	echo -n "sleep $N"
	while [ "$N" -gt 0 ]; do
		sleep 1
		N=$((N-1))
		echo -ne "\rsleep $N"
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
