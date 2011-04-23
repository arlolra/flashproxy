#!/usr/bin/env python

import getopt
import socket
import sys

DEFAULT_ADDRESS = "0.0.0.0"
DEFAULT_PORT = 843

POLICY = """\
<cross-domain-policy>
<allow-access-from domain="*" to-ports="*"/>
</cross-domain-policy>
\0"""

class options(object):
    pass

def usage(f = sys.stdout):
    print """\
Usage: %(progname)s <OPTIONS> [HOST] [PORT]
Serve a Flash crossdomain policy. By default HOST is %(addr)s
and PORT is %(port)d.
  -h, --help  show this help.\
""" % {"progname": sys.argv[0], "addr": DEFAULT_ADDRESS, "port": DEFAULT_PORT }

opts, args = getopt.gnu_getopt(sys.argv[1:], "h", ["help"])
for o, a in opts:
    if o == "-h" or o == "--help":
        usage()
        sys.exit()
if len(args) == 0:
    address = (DEFAULT_ADDRESS, DEFAULT_PORT)
elif len(args) == 1:
    # Either HOST or PORT may be omitted; figure out which one.
    if args[0].isdigit():
        address = (DEFAULT_ADDRESS, args[0])
    else:
        address = (args[0], DEFAULT_PORT)
elif len(args) == 2:
    address = (args[0], args[1])
else:
    usage(sys.stderr)
    sys.exit(1)

addrinfo = socket.getaddrinfo(address[0], address[1], 0, socket.SOCK_STREAM, socket.IPPROTO_TCP)[0]

s = socket.socket(addrinfo[0], addrinfo[1], addrinfo[2])
s.setsockopt(socket.SOL_SOCKET, socket.SO_REUSEADDR, 1)
s.bind(addrinfo[4])
s.listen(10)
while True:
    (c, c_addr) = s.accept()
    c.sendall(POLICY)
    c.close()
