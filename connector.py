#!/usr/bin/env python

import getopt
import httplib
import re
import select
import socket
import sys
import urllib

DEFAULT_REMOTE_ADDRESS = "0.0.0.0"
DEFAULT_REMOTE_PORT = 9000
DEFAULT_LOCAL_ADDRESS = "localhost"
DEFAULT_LOCAL_PORT = 9001
DEFAULT_FACILITATOR_PORT = 9002

def usage(f = sys.stdout):
    print >> f, """\
Usage: %(progname)s -f FACILITATOR[:PORT] [LOCAL][:PORT] [REMOTE][:PORT]
Wait for connections on a local and a remote port. When any pair of connections
exists, data is ferried between them until one side is closed. By default
LOCAL is "%(local)s" and REMOTE is "%(remote)s".

If the -f option is given, then the REMOTE address is advertised to the given
FACILITATOR.
  -f, --facilitator=HOST[:PORT]  advertise willingness to receive connections to
                                   HOST:PORT. By default PORT is %(fac_port)d.
  -h, --help                     show this help.\
""" % {
    "progname": sys.argv[0],
    "local": format_addr((DEFAULT_LOCAL_ADDRESS, DEFAULT_LOCAL_PORT)),
    "remote": format_addr((DEFAULT_REMOTE_ADDRESS, DEFAULT_REMOTE_PORT)),
    "fac_port": DEFAULT_FACILITATOR_PORT,
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

def format_addr(addr):
    host, port = addr
    if not host:
        return u":%d" % port
    # Numeric IPv6 address?
    try:
        addrs = socket.getaddrinfo(host, port, 0, socket.SOCK_STREAM, socket.IPPROTO_TCP, socket.AI_NUMERICHOST)
        af = addrs[0][0]
    except socket.gaierror, e:
        af = 0
    if af == socket.AF_INET6:
        return u"[%s]:%d" % (host, port)
    else:
        return u"%s:%d" % (host, port)

facilitator_addr = None

opts, args = getopt.gnu_getopt(sys.argv[1:], "f:h", ["facilitator", "help"])
for o, a in opts:
    if o == "-f" or o == "--facilitator":
        facilitator_addr = parse_addr_spec(a, None, DEFAULT_FACILITATOR_PORT)
    elif o == "-h" or o == "--help":
        usage()
        sys.exit()

if len(args) == 0:
    local_addr = (DEFAULT_LOCAL_ADDRESS, DEFAULT_LOCAL_PORT)
    remote_addr = (DEFAULT_REMOTE_ADDRESS, DEFAULT_REMOTE_PORT)
elif len(args) == 1:
    local_addr = parse_addr_spec(args[0], DEFAULT_LOCAL_ADDRESS, DEFAULT_LOCAL_PORT)
    remote_addr = (DEFAULT_REMOTE_ADDRESS, DEFAULT_REMOTE_PORT)
elif len(args) == 2:
    local_addr = parse_addr_spec(args[0], DEFAULT_LOCAL_ADDRESS, DEFAULT_LOCAL_PORT)
    remote_addr = parse_addr_spec(args[1], DEFAULT_REMOTE_ADDRESS, DEFAULT_REMOTE_PORT)
else:
    usage(sys.stderr)
    sys.exit(1)

def listen_socket(addr):
    """Return a nonblocking socket listening on the given address."""
    addrinfo = socket.getaddrinfo(addr[0], addr[1], 0, socket.SOCK_STREAM, socket.IPPROTO_TCP)[0]
    s = socket.socket(addrinfo[0], addrinfo[1], addrinfo[2])
    s.setsockopt(socket.SOL_SOCKET, socket.SO_REUSEADDR, 1)
    s.bind(addr)
    s.listen(10)
    s.setblocking(0)
    return s

def register(addr, port):
    spec = format_addr((None, port))
    print "Registering \"%s\" with %s." % (spec, format_addr(addr))
    http = httplib.HTTPConnection(*addr)
    http.request("POST", "/", urllib.urlencode({"client": spec}))
    http.close()

def match_proxies():
    while local_pool and remote_pool:
        remote = remote_pool.pop(0)
        local = local_pool.pop(0)
        remote_addr, remote_port = remote.getpeername()
        local_addr, local_port = local.getpeername()
        print "Linking %s and %s." % (format_addr(local.getpeername()), format_addr(remote.getpeername()))
        remote_for[local] = remote
        local_for[remote] = local

local_s = listen_socket(local_addr)
remote_s = listen_socket(remote_addr)

local_pool = []
remote_pool = []

local_for = {}
remote_for = {}

if facilitator_addr:
    register(facilitator_addr, remote_addr[1])

while True:
    rset = [remote_s, local_s] + remote_for.keys() + local_for.keys()
    rset, _, _ = select.select(rset, [], [])
    for fd in rset:
        if fd == remote_s:
            remote_c, addr = fd.accept()
            print "Remote connection from %s." % format_addr(addr)
            remote_pool.append(remote_c)
        elif fd == local_s:
            local_c, addr = fd.accept()
            print "Local connection from %s." % format_addr(addr)
            local_pool.append(local_c)
        elif fd in local_for:
            local = local_for[fd]
            data = fd.recv(1024)
            if not data:
                print "EOF from remote %s." % format_addr(fd.getpeername())
                fd.close()
                local.close()
                del local_for[fd]
                del remote_for[local]
            else:
                local.sendall(data)
        elif fd in remote_for:
            remote = remote_for[fd]
            data = fd.recv(1024)
            if not data:
                print "EOF from local %s." % format_addr(fd.getpeername())
                fd.close()
                remote.close()
                del remote_for[fd]
                del local_for[remote]
            else:
                remote.sendall(data)
        match_proxies()
