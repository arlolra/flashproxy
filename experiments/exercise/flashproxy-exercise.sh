#!/bin/sh

DATE=$(date +"%Y-%m-%d-%H:%M")
LOG="log-$DATE"

# To get cron mail:
# ./exercise.sh 2>&1 | tee "$LOG"
# To not get cron mail:
./exercise.sh &> "$LOG"
