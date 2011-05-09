#!/usr/bin/env python

import sys
import re
import socket
import getopt
import select
import urllib
import httplib

DEFAULT_RELAY_ADDRESS   = "localhost"
DEFAULT_RELAY_PORT      = 9001
DEFAULT_LISTEN_ADDRESS  = "0.0.0.0"
DEFAULT_LISTEN_PORT     = 9002

""" FIXME: update when finished with writing program. """
def usage(f = sys.stdout):
    print >> f, """
Usage: %(progname)s
Maintains connections to multiple proxies. For any group of proxies that
serve a unique client, only one proxy of that group is "activated" at
any one time and connects to the relay. When this proxy shuts down the
client selects another proxy to use and this program will note the newly
activated proxy and connect it to the relay.

    -h, --help                          show help.
""" % {
    "progname": sys.argv[0],
}

def parse_addr_spec(spec, defhost = None, defport = None):
    host = None
    port = None
    m = None
    # IPv6 syntax.
    if not m:
        m = re.match(r'^\[(.+)\]:(\d+)$', spec)
        if m:
            host, port = m.groups()
            af = socket.AF_INET6
    if not m:
        m = re.match(r'^\[(.+)\]:?$', spec)
        if m:
            host, = m.groups()
            af = socket.AF_INET6
    # IPv4 syntax.
    if not m:
        m = re.match(r'^(.+):(\d+)$', spec)
        if m:
            host, port = m.groups()
            af = socket.AF_INET
    if not m:
        m = re.match(r'^:?(\d+)$', spec)
        if m:
            port, = m.groups()
            af = 0
    if not m:
        host = spec
        af = 0
    host = host or defhost
    port = port or defport
    if not (host and port):
        raise ValueError("Bad address specification \"%s\"" % spec)
    return host, int(port)

def listen_socket(addr):
    """Return a nonblocking socket listenting on the given address."""
    addrinfo = socket.getaddrinfo(addr[0], addr[1], 0,
socket.SOCK_STREAM, socket.IPPROTO_TCP)[0]
    s = socket.socket(addrinfo[0], addrinfo[1], addrinfo[2])
    s.setsockopt(socket.SOL_SOCKET, socket.SO_REUSEADDR, 1)
    s.bind(addr)
    s.listen(10)
    s.setblocking(0)
    return s


if __name__ == "__main__": 
    """ Parameter defaults. """
    relay_addr = (DEFAULT_RELAY_ADDRESS, DEFAULT_RELAY_PORT)
    listen_addr = (DEFAULT_LISTEN_ADDRESS, DEFAULT_LISTEN_PORT)

    """ Parse options. """
    opts, args = getopt.gnu_getopt(sys.argv[1:], "r:l:h", ["relay",
"listen", "help"])
    for o, a in opts:
        if o == "-r" or o == "--relay":
            relay_addr = parse_addr_spec(a, None, DEFAULT_RELAY_PORT)
        elif o == "-l" or o == "--listen":
            listen_addr = parse_addr_spec(a, None, DEFAULT_LISTEN_PORT)
        elif o == "-h" or o == "--help":
            usage()
            sys.exit()

    """ Connect to relay. """
    addrinfo = socket.getaddrinfo(relay_addr[0], relay_addr[1], 0,
socket.SOCK_STREAM, socket.IPPROTO_TCP)[0]
    relay_s = socket.socket(addrinfo[0], addrinfo[1], addrinfo[2])
