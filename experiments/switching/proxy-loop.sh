#!/bin/bash

# Runs overlapping flash proxy instances in a loop.
# Usage: /proxy-loop.sh <URL> PROFILE1 PROFILE2

# The profiles need to have the open_newwindow configuration option set
# properly. See ../README.
#   browser.link.open_newwindow=1 (default is 3)

. ../common.sh

URL=$1
PROFILE_1=$2
PROFILE_2=$3

# OVERLAP must be at most half of PERIOD.
PERIOD=10
OVERLAP=2

ensure_browser_started "$PROFILE_1"
browser_clear "$PROFILE_1"
ensure_browser_started "$PROFILE_2"
browser_clear "$PROFILE_2"

sleep 1

while true; do
	echo "1 on"
	firefox -P "$PROFILE_1" -remote "openurl($URL)"
	sleep $OVERLAP
	echo "2 off"
	firefox -P "$PROFILE_2" -remote "openurl(about:blank)"
	sleep $(($PERIOD - (2 * $OVERLAP)))
	echo "2 on"
	firefox -P "$PROFILE_2" -remote "openurl($URL)"
	sleep $OVERLAP
	echo "1 off"
	firefox -P "$PROFILE_1" -remote "openurl(about:blank)"
	sleep $(($PERIOD - (2 * $OVERLAP)))
done
