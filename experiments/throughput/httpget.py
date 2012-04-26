#!/usr/bin/env python

# A simple HTTP downloader that discards what it downloads and prints the time
# taken to download. We use this rather than "time wget" because the latter
# includes time taken to establish (and possibly retry) the connection.

import getopt
import sys
import time
import urllib2

BLOCK_SIZE = 65536

label = None

opts, args = getopt.gnu_getopt(sys.argv[1:], "l:")
for o, a in opts:
    if o == "-l":
        label = a

try:
    stream = urllib2.urlopen(args[0], timeout=100)
    start_time = time.time()
    while stream.read(BLOCK_SIZE):
        pass
    end_time = time.time()
    if label:
        print "%s %.3f" % (label, end_time - start_time)
    else:
        print "%.3f" % (end_time - start_time)
except:
    if label:
        print "%s error" % label
    else:
        print "error"
