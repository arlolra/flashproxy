#!/bin/bash

# Usage: ./remote-tor-alternating.sh
#
# Tests a Tor download over alternating flash proxies.

. ../common.sh

PROFILE_1=flashexp1
PROFILE_2=flashexp2
PROXY_URL="http://127.0.0.1:8000/swfcat.swf?facilitator=127.0.0.1:9002"
DATA_FILE_NAME="$FLASHPROXY_DIR/dump"

# Declare an array.
declare -a PIDS_TO_KILL
stop() {
	browser_clear "$PROFILE_1"
	browser_clear "$PROFILE_2"
	if [ -n "${PIDS_TO_KILL[*]}" ]; then
		echo "Kill pids ${PIDS_TO_KILL[@]}."
		kill "${PIDS_TO_KILL[@]}"
	fi
	exit
}
trap stop EXIT

echo "Start web server."
"$THTTPD" -D -d "$FLASHPROXY_DIR" -p 8000 &
PIDS_TO_KILL+=($!)

echo "Start facilitator."
"$FLASHPROXY_DIR"/facilitator.py -d --relay tor1.bamsoftware.com >/dev/null &
PIDS_TO_KILL+=($!)
visible_sleep 2

echo "Start connector."
"$FLASHPROXY_DIR"/connector.py --facilitator 127.0.0.1 >/dev/null &
PIDS_TO_KILL+=($!)
visible_sleep 1

echo "Start Tor."
"$TOR" -f "$FLASHPROXY_DIR"/torrc &
PIDS_TO_KILL+=($!)

echo "Start browsers."
ensure_browser_started "$PROFILE_1"
ensure_browser_started "$PROFILE_2"

./proxy-loop.sh "$PROXY_URL" "$PROFILE_1" "$PROFILE_2" >/dev/null 2>&1  &
PIDS_TO_KILL+=($!)

# Let Tor bootstrap.
visible_sleep 15

time torify wget http://torperf.torproject.org/.5mbfile -t 0 -O /dev/null
