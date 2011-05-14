#!/usr/bin/env python

import getopt
import os
import socket
import sys
import xml.sax.saxutils

DEFAULT_ADDRESS = "0.0.0.0"
DEFAULT_PORT = 843
DEFAULT_DOMAIN = "*"
DEFAULT_PORTS = "*"

class options(object):
    daemonize = False
    domain = DEFAULT_DOMAIN
    ports = DEFAULT_PORTS

def usage(f = sys.stdout):
    print >> f, """\
Usage: %(progname)s <OPTIONS> [HOST] [PORT]
Serve a Flash crossdomain policy. By default HOST is \"%(addr)s\"
and PORT is %(port)d.
  --daemon             daemonize (Unix only).
  -d, --domain=DOMAIN  limit access to the given DOMAIN (default \"%(domain)s\").
  -h, --help           show this help.
  -p, --ports=PORTS    limit access to the given PORTS (default \"%(ports)s\").\
""" % {
    "progname": sys.argv[0],
    "addr": DEFAULT_ADDRESS,
    "port": DEFAULT_PORT,
    "domain": DEFAULT_DOMAIN,
    "ports": DEFAULT_PORTS,
}

def make_policy(domain, ports):
    return """\
<cross-domain-policy>
<allow-access-from domain="%s" to-ports="%s"/>
</cross-domain-policy>
\0""" % (xml.sax.saxutils.escape(domain), xml.sax.saxutils.escape(ports))

opts, args = getopt.gnu_getopt(sys.argv[1:], "d:hp:", ["daemon", "domain", "help", "ports"])
for o, a in opts:
    if o == "--daemon":
        options.daemonize = True
    elif o == "-h" or o == "--help":
        usage()
        sys.exit()
    elif o == "-d" or o == "--domain":
        options.domain = a
    elif o == "-p" or o == "--ports":
        options.ports = a

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

policy = make_policy(options.domain, options.ports)

addrinfo = socket.getaddrinfo(address[0], address[1], 0, socket.SOCK_STREAM, socket.IPPROTO_TCP)[0]

s = socket.socket(addrinfo[0], addrinfo[1], addrinfo[2])
s.setsockopt(socket.SOL_SOCKET, socket.SO_REUSEADDR, 1)
s.bind(addrinfo[4])
s.listen(10)

if options.daemonize:
    if os.fork() != 0:
        sys.exit(0)

while True:
    (c, c_addr) = s.accept()
    c.sendall(policy)
    c.close()
