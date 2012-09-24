#!/usr/bin/env python

# Makes a graph of flash proxy counts from a facilitator log.

import datetime
import getopt
import re
import sys

import matplotlib
import matplotlib.pyplot as plt
import numpy as np

POLL_INTERVAL = 10.0

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

class Block(object):
    def __init__(self, ip, date):
        self.ip = ip
        self.begin_date = date
        self.end_date = date

prev_date = None
seen = {}
current = []
blocks = []
for line in input_file:
    m = re.match(r'(\d+-\d+-\d+ \d+:\d+:\d+) proxy ([\d.]+):\d+ connects', line)
    if not m:
        continue
    date_str, ip = m.groups()
    date = datetime.datetime.strptime(date_str, "%Y-%m-%d %H:%M:%S")

    if prev_date is None or prev_date != date.date():
        print date.date()
        prev_date = date.date()

    block = seen.get(ip)
    if block is None:
        block = Block(ip, date)
        seen[ip] = block
        current.append(block)
        # Poor man's priority queue: keep the first to expire (oldest) at the
        # tail of the list.
        current.sort(key = lambda x: x.end_date, reverse = True)
    else:
        block.end_date = date

    # Delete all those that are now expired.
    while current:
        block = current[-1]
        delta = timedelta_to_seconds(date - block.end_date)
        if delta > POLL_INTERVAL * 1.5:
            blocks.append(block)
            current.pop()
            del seen[block.ip]
        else:
            break

events = []
for block in blocks:
    events.append(("begin", block.begin_date))
    events.append(("end", block.end_date + datetime.timedelta(seconds = POLL_INTERVAL / 2)))
# Handle any still alive at the end.
while current:
    block = current[-1]
    events.append(("begin", block.begin_date))
    events.append(("end", date))
    current.pop()
    del seen[block.ip]

events.sort(key = lambda x: x[1])

data = []
num = 0
for i, event in enumerate(events):
    t = event[1]
    data.append((t, num))
    if event[0] == "begin":
        num += 1
    elif event[0] == "end":
        num -= 1
    data.append((t, num))
data = np.array(data)

fig = plt.figure()
ax = fig.add_axes([0.10, 0.30, 0.88, 0.60])
ax.set_ylabel(u"Number of proxies", fontsize=8)
fig.set_size_inches((8, 3))

ax.tick_params(direction="out", top="off", right="off")
ax.set_frame_on(False)
ax.xaxis.set_major_formatter(matplotlib.ticker.FuncFormatter(format_date))
fig.autofmt_xdate()

plt.fill_between(data[:,0], data[:,1], linewidth=0, color="black")

fig.savefig(output_file_name)
