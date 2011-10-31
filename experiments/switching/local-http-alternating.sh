#!/bin/bash

# Usage: ./local-http-alternating.sh [OUTPUT_FILENAME]
#
# Tests a download over alternating flash proxies. If OUTPUT_FILENAME is
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
	browser_clear "$PROFILE_2"
	if [ -n "${PIDS_TO_KILL[*]}" ]; then
		echo "Kill pids ${PIDS_TO_KILL[@]}."
		kill "${PIDS_TO_KILL[@]}"
	fi
	echo "Delete data file."
	rm -f "$DATA_FILE_NAME"
	exit
}
trap stop EXIT

echo "Create data file."
dd if=/dev/null of="$DATA_FILE_NAME" bs=1M seek=1024 2>/dev/null || exit

echo "Start web server."
"$THTTPD" -D -d "$FLASHPROXY_DIR" -p 8000 &
PIDS_TO_KILL+=($!)

echo "Start facilitator."
"$FLASHPROXY_DIR"/facilitator.py -d --relay 127.0.0.1:8000 >/dev/null &
PIDS_TO_KILL+=($!)
visible_sleep 2

echo "Start connector."
"$FLASHPROXY_DIR"/connector.py --facilitator 127.0.0.1 >/dev/null &
PIDS_TO_KILL+=($!)
visible_sleep 1

echo "Start browsers."
ensure_browser_started "$PROFILE_1"
ensure_browser_started "$PROFILE_2"

./proxy-loop.sh "$PROXY_URL" "$PROFILE_1" "$PROFILE_2" >/dev/null 2>&1  &
PIDS_TO_KILL+=($!)
visible_sleep 1

echo "Start socat."
"$SOCAT" TCP-LISTEN:2000,reuseaddr,fork SOCKS4A:127.0.0.1:dummy:0,socksport=9001 &
PIDS_TO_KILL+=($!)
visible_sleep 1


if [ -n "$OUTPUT_FILENAME" ]; then
	real_time wget http://127.0.0.1:2000/dump -t 0 -O /dev/null >> "$OUTPUT_FILENAME"
else
	real_time wget http://127.0.0.1:2000/dump -t 0 -O /dev/null
fi
