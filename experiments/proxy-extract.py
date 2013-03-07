#!/usr/bin/env python

import datetime
import getopt
import re
import sys

def usage(f = sys.stdout):
    print >> f, """\
Usage: %s [INPUTFILE]
Extract proxy connections from a facilitator log. Each output line is
    date\tcount\n
where count is the approximate poll interval in effect at date.

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

def timedelta_to_seconds(delta):
    return delta.days * (24 * 60 * 60) + delta.seconds + delta.microseconds / 1000000.0

# commit 49de7bf689ee989997a1edbf2414a7bdbc2164f9
# Author: David Fifield <david@bamsoftware.com>
# Date:   Thu Jan 3 21:01:39 2013 -0800
#
#     Bump poll interval from 10 s to 60 s.
#
# commit 69d429db12cedc90dac9ccefcace80c86af7eb51
# Author: David Fifield <david@bamsoftware.com>
# Date:   Tue Jan 15 14:02:02 2013 -0800
#
#     Increase facilitator_poll_interval from 1 m to 10 m.

BEGIN_60S = datetime.datetime(2013, 1, 3, 21, 0, 0)
BEGIN_600S = datetime.datetime(2013, 1, 15, 14, 0, 0)

# Proxies refresh themselves once a day, so interpolate across a day when the
# polling interval historically changed.
def get_poll_interval(date):
    if date < BEGIN_60S:
        return 10
    elif BEGIN_60S <= date < BEGIN_60S + datetime.timedelta(1):
        return timedelta_to_seconds(date-BEGIN_60S) / timedelta_to_seconds(datetime.timedelta(1)) * (60-10) + 10
    elif date < BEGIN_600S:
        return 60
    elif BEGIN_600S <= date < BEGIN_600S + datetime.timedelta(1):
        return timedelta_to_seconds(date-BEGIN_600S) / timedelta_to_seconds(datetime.timedelta(1)) * (600-60) + 60
    else:
        return 600

prev_output = None
count = 0.0

for line in input_file:
    m = re.match(r'^(\d+-\d+-\d+ \d+:\d+:\d+) proxy gets', line)
    if not m:
        continue
    date_str, = m.groups()
    date = datetime.datetime.strptime(date_str, "%Y-%m-%d %H:%M:%S")

    count += get_poll_interval(date)

    rounded_date = date.replace(minute=0, second=0, microsecond=0)
    prev_output = prev_output or rounded_date
    if prev_output is None or rounded_date != prev_output:
        avg = float(count) / 10.0
        print date.strftime("%Y-%m-%d %H:%M:%S") + "\t" + "%.2f" % avg
        prev_output = rounded_date
        count = 0.0
