#!/usr/bin/env python

import datetime
import getopt
import re
import sys

def usage(f = sys.stdout):
    print >> f, """\
Usage: %s [INPUTFILE]
Extract client connections from a facilitator log. Each output line is
    date\tcount\n
where count is the number of client requests in that hour.

  -h, --help           show this help.
""" % sys.argv[0]

opts, args = getopt.gnu_getopt(sys.argv[1:], "h", ["help"])
for o, a in opts:
    if o == "-h" or o == "--help":
        usage()
        sys.exit()

if len(args) == 0:
    input_file = sys.stdin
elif len(args) == 1:
    input_file = open(args[0])
else:
    usage()
    sys.exit()

prev_output = None
count = 0.0

for line in input_file:
    m = re.match(r'^(\d+-\d+-\d+ \d+:\d+:\d+) client', line)
    if not m:
        continue
    date_str, = m.groups()
    date = datetime.datetime.strptime(date_str, "%Y-%m-%d %H:%M:%S")

    count += 1

    rounded_date = date.replace(minute=0, second=0, microsecond=0)
    prev_output = prev_output or rounded_date
    if prev_output is None or rounded_date != prev_output:
        avg = float(count)
        print date.strftime("%Y-%m-%d %H:%M:%S") + "\t" + "%.2f" % avg
        prev_output = rounded_date
        count = 0.0
