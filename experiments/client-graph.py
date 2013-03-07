#!/usr/bin/env python

# Makes a graph of flash proxy client counts from a facilitator log.

import datetime
import getopt
import re
import sys

import matplotlib
import matplotlib.pyplot as plt
import numpy as np

START_DATE = datetime.datetime(2012, 12, 15)

def usage(f = sys.stdout):
    print >> f, """\
Usage: %s -o OUTPUT [INPUTFILE]
Makes a graph of flash proxy counts from a facilitator log.

  -h, --help           show this help.
  -o, --output=OUTPUT  output file name (required).\
""" % sys.argv[0]

output_file_name = None

opts, args = getopt.gnu_getopt(sys.argv[1:], "ho:", ["help", "output="])
for o, a in opts:
    if o == "-h" or o == "--help":
        usage()
        sys.exit()
    elif o == "-o" or o == "--output":
        output_file_name = a

if not output_file_name:
    usage()
    sys.exit()

if len(args) == 0:
    input_file = sys.stdin
elif len(args) == 1:
    input_file = open(args[0])
else:
    usage()
    sys.exit()

def format_date(d, pos=None):
    d = matplotlib.dates.num2date(d)
    return d.strftime("%B %d")

def timedelta_to_seconds(delta):
    return delta.days * (24 * 60 * 60) + delta.seconds + delta.microseconds / 1000000.0

prev_output = None
count = 0

data = []

for line in input_file:
    m = re.match(r'^(\d+-\d+-\d+ \d+:\d+:\d+) client', line)
    if not m:
        continue
    date_str, = m.groups()
    date = datetime.datetime.strptime(date_str, "%Y-%m-%d %H:%M:%S")

    if date < START_DATE:
        continue

    count += 1

    rounded_date = date.replace(minute=0, second=0, microsecond=0)
    prev_output = prev_output or rounded_date
    if prev_output is None or rounded_date != prev_output:
        delta = timedelta_to_seconds(date - prev_output)
        # avg = float(count) / delta
        avg = float(count)
        data.append((date, avg))
        print date, avg
        prev_output = rounded_date
        count = 0

data = np.array(data)

fig = plt.figure()
ax = fig.add_axes([0.10, 0.30, 0.88, 0.60])
ax.set_ylabel(u"Number of clients", fontsize=8)
fig.set_size_inches((8, 3))

ax.tick_params(direction="out", top="off", right="off")
ax.set_frame_on(False)
ax.xaxis.set_major_formatter(matplotlib.ticker.FuncFormatter(format_date))
fig.autofmt_xdate()

plt.fill_between(data[:,0], data[:,1], linewidth=0, color="black")

fig.savefig(output_file_name)
