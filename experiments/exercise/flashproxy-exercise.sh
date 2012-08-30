#!/bin/sh

# Usage (for example in crontab for hourly tests):
#   0 *    *   *   *   cd /path/flashproxy-exercise && ./flashproxy-exercise.sh

DATE=$(date +"%Y-%m-%d-%H:%M")
LOG="log-$DATE"

(./exercise.sh &> "$LOG") || cat "$LOG"
