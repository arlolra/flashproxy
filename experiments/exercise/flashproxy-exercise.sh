#!/bin/sh

# Usage (for example in crontab for hourly tests):
#   0 *    *   *   *   cd /path/flashproxy-exercise && ./flashproxy-exercise.sh

LOGDIR=log
DATE=$(date +"%Y-%m-%d-%H:%M")
LOG="$LOGDIR/log-$DATE"

mkdir -p "$LOGDIR"
(./exercise.sh &> "$LOG") || cat "$LOG"
