#!/bin/bash

# This script registers with the flash proxy facilitator, tries to download
# check.torproject.org, and saves a timestamped log file.

FLASHPROXY_DIR="$HOME/flashproxy"
TOR="$HOME/tor/src/or/tor"
LOCAL_PORT=1080
REMOTE_PORT=7070

declare -a PIDS_TO_KILL
stop() {
	if [ -n "${PIDS_TO_KILL[*]}" ]; then
		echo "Kill pids ${PIDS_TO_KILL[@]}."
		kill "${PIDS_TO_KILL[@]}"
	fi
	exit
}
trap stop EXIT

date

"$FLASHPROXY_DIR"/connector.py -f tor-facilitator.bamsoftware.com ":$LOCAL_PORT" ":$REMOTE_PORT" &
PIDS_TO_KILL+=($!)

sleep 20

"$TOR" UseBridges 1 Bridge 127.0.0.1:9001 Socks4Proxy 127.0.0.1:$LOCAL_PORT &
PIDS_TO_KILL+=($!)

sleep 60

curl --retry 5 --socks4a 127.0.0.1:9050 http://check.torproject.org/
