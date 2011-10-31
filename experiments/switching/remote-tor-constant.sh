#!/bin/bash

# Usage: ./remote-tor-constant.sh
#
# Tests a Tor download over an uninterrupted flash proxy. If OUTPUT_FILENAME is
# supplied, appends the time measurement to that file.

. ../common.sh

PROFILE_1=flashexp1
PROFILE_2=flashexp2
PROXY_URL="http://127.0.0.1:8000/swfcat.swf?facilitator=127.0.0.1:9002"
DATA_FILE_NAME="$FLASHPROXY_DIR/dump"
OUTPUT_FILENAME="$1"

# Declare an array.
declare -a PIDS_TO_KILL
stop() {
	browser_clear "$PROFILE_1"
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
browser_goto "$PROFILE_1" "$PROXY_URL"

# Let Tor bootstrap.
visible_sleep 15

if [ -n "$OUTPUT_FILENAME" ]; then
	real_time torify wget http://torperf.torproject.org/.5mbfile -t 0 -O /dev/null >> "$OUTPUT_FILENAME"
else
	real_time torify wget http://torperf.torproject.org/.5mbfile -t 0 -O /dev/null
fi
