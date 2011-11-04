#!/bin/bash

# Usage: ./remote-tor-direct.sh [OUTPUT_FILENAME]
#
# Tests a Tor download without using a flash proxy. If OUTPUT_FILENAME is
# supplied, appends the time measurement to that file.

. ../common.sh

DATA_FILE_NAME="$FLASHPROXY_DIR/dump"
OUTPUT_FILENAME="$1"

# Declare an array.
declare -a PIDS_TO_KILL
stop() {
	if [ -n "${PIDS_TO_KILL[*]}" ]; then
		echo "Kill pids ${PIDS_TO_KILL[@]}."
		kill "${PIDS_TO_KILL[@]}"
	fi
	echo "Delete data file."
	rm -f "$DATA_FILE_NAME"
	exit
}
trap stop EXIT

echo "Start Tor."
"$TOR" -f torrc.bridge &
PIDS_TO_KILL+=($!)

# Let Tor bootstrap.
visible_sleep 15

if [ -n "$OUTPUT_FILENAME" ]; then
	real_time torify wget http://torperf.torproject.org/.5mbfile --wait=0 --waitretry=0 -c -t 0 -O "$DATA_FILE_NAME" >> "$OUTPUT_FILENAME"
else
	real_time torify wget http://torperf.torproject.org/.5mbfile --wait=0 --waitretry=0 -c -t 0 -O "$DATA_FILE_NAME"
fi
