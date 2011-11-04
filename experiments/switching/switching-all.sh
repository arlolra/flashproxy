#!/bin/bash

# Usage: ./switching-all.sh [-n NUM_ITERATIONS]
#
# Runs the switching experiment scripts several times and stores the results in
# log files
# 	local-http-constant-DATE.log
# 	local-http-alternating-DATE.log
# 	remote-tor-constant-DATE.log
# 	remote-tor-alternating-DATE.log
# where DATE is the current date.

. ../common.sh

NUM_ITERATIONS=1

while getopts "n:" OPTNAME; do
	if [ "$OPTNAME" == n ]; then
		NUM_ITERATIONS="$OPTARG"
	fi
done

DATE="$(date --iso)"

> "local-http-constant-$DATE.log"
repeat $NUM_ITERATIONS ./local-http-constant.sh "local-http-constant-$DATE.log"

> "local-http-alternating-$DATE.log"
repeat $NUM_ITERATIONS ./local-http-alternating.sh "local-http-alternating-$DATE.log"

> "remote-tor-direct-$DATE.log"
repeat $NUM_ITERATIONS ./remote-tor-direct.sh "remote-tor-direct-$DATE.log"

> "remote-tor-constant-$DATE.log"
repeat $NUM_ITERATIONS ./remote-tor-constant.sh "remote-tor-constant-$DATE.log"

> "remote-tor-alternating-$DATE.log"
repeat $NUM_ITERATIONS ./remote-tor-alternating.sh "remote-tor-alternating-$DATE.log"
