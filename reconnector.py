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
    addrinfo = socket.getaddrinfo(addr[0], addr[1], 0, socket.SOCK_STREAM, socket.IPPROTO_TCP)[0]
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
    
    """ Mutual dictionaries for linking connections. """
    relay_for = {}
    proxy_for = {}

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

    """ Setup listening socket for proxies. """
    listen_s = listen_socket(listen_addr)

    print "Listening on " + str(listen_addr) + " for proxy connections."

    """ Setup relay address information. """
    relay_addrinfo = socket.getaddrinfo(relay_addr[0], relay_addr[1], 0, socket.SOCK_STREAM, socket.IPPROTO_TCP)[0]

    while True:
        rset = [listen_s] + relay_for.keys() + proxy_for.keys()
        rset, _, _ = select.select(rset, [], [], 0)
        for fd in rset:
            """ Connecton on listening socket. """
            if fd == listen_s:
                proxy_s, addr = fd.accept()
                print "Proxy connection from %s." % format_addr(addr)
                
                """ New connection to relay. """
                try:
                    relay_s = socket.socket(relay_addrinfo[0], relay_addrinfo[1], relay_addrinfo[2])
                except socket.error, msg:
                    print msg
                    relay_s = None

                try:
                    relay_s.connect(relay_addrinfo[4])
                except socket.error, msg:
                    print msg
                    relay_s.close()
                    relay_s = None

                if relay_s is None:
                    print "ERROR: Could not open socket to relay " + str(relay_addr)
                    sys.exit(1)

                """ Pair up the sockets. """
                relay_for[proxy_s] = relay_s
                proxy_for[relay_s] = proxy_s

                """ Data from a proxy. Forward to relay. """
            elif fd in relay_for:
                relay = relay_for[fd]
                data = fd.recv(1024)
                if not data:
                    print "EOF from proxy %s." % format_addr(fd.getpeername())
                    fd.close()
                    relay.close()
                    del relay_for[fd]
                    del proxy_for[relay]
                else:
                    print "Sending " + str(len(data)) + " bytes to relay from " + format_addr(fd.getpeername()) 
                    relay.sendall(data)
            
                """ Data from a relay. Forward to proxy. """
            elif fd in proxy_for:
                proxy = proxy_for[fd]
                data = fd.recv(1024)
                if not data:
                    print "EOF from relay %s." % format_addr(fd.getpeername())
                    fd.close()
                    proxy.close()
                    del proxy_for[fd]
                    del relay_for[proxy]
                else:
                    print "Sending " + str(len(data)) + " bytes from relay to " + format_addr(proxy.getpeername())
                    proxy.sendall(data)

