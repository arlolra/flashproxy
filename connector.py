#!/usr/bin/env python

import getopt
import httplib
import re
import select
import socket
import struct
import sys
import time
import urllib
import xml.sax.saxutils

DEFAULT_REMOTE_ADDRESS = "0.0.0.0"
DEFAULT_REMOTE_PORT = 9000
DEFAULT_LOCAL_ADDRESS = "127.0.0.1"
DEFAULT_LOCAL_PORT = 9001
DEFAULT_FACILITATOR_PORT = 9002

class options(object):
    local_addr = None
    remote_addr = None
    facilitator_addr = None

# We accept up to this many bytes from a local socket not yet matched with a
# remote before disconnecting it.
UNCONNECTED_LOCAL_BUFFER_LIMIT = 10240

def usage(f = sys.stdout):
    print >> f, """\
Usage: %(progname)s -f FACILITATOR[:PORT] [LOCAL][:PORT] [REMOTE][:PORT]
Wait for connections on a local and a remote port. When any pair of connections
exists, data is ferried between them until one side is closed. By default
LOCAL is "%(local)s" and REMOTE is "%(remote)s".

The local connection acts as a SOCKS4a proxy, but the host and port in the SOCKS
request are ignored and the local connection is always joined to a remote
connection.

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
        m = re.match(ur'^\[(.+)\]:(\d+)$', spec)
        if m:
            host, port = m.groups()
            af = socket.AF_INET6
    if not m:
        m = re.match(ur'^\[(.+)\]:?$', spec)
        if m:
            host, = m.groups()
            af = socket.AF_INET6
    # IPv4 syntax.
    if not m:
        m = re.match(ur'^(.+):(\d+)$', spec)
        if m:
            host, port = m.groups()
            af = socket.AF_INET
    if not m:
        m = re.match(ur'^:?(\d+)$', spec)
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

opts, args = getopt.gnu_getopt(sys.argv[1:], "f:h", ["facilitator", "help"])
for o, a in opts:
    if o == "-f" or o == "--facilitator":
        options.facilitator_addr = parse_addr_spec(a, None, DEFAULT_FACILITATOR_PORT)
    elif o == "-h" or o == "--help":
        usage()
        sys.exit()

if len(args) == 0:
    options.local_addr = (DEFAULT_LOCAL_ADDRESS, DEFAULT_LOCAL_PORT)
    options.remote_addr = (DEFAULT_REMOTE_ADDRESS, DEFAULT_REMOTE_PORT)
elif len(args) == 1:
    options.local_addr = parse_addr_spec(args[0], DEFAULT_LOCAL_ADDRESS, DEFAULT_LOCAL_PORT)
    options.remote_addr = (DEFAULT_REMOTE_ADDRESS, DEFAULT_REMOTE_PORT)
elif len(args) == 2:
    options.local_addr = parse_addr_spec(args[0], DEFAULT_LOCAL_ADDRESS, DEFAULT_LOCAL_PORT)
    options.remote_addr = parse_addr_spec(args[1], DEFAULT_REMOTE_ADDRESS, DEFAULT_REMOTE_PORT)
else:
    usage(sys.stderr)
    sys.exit(1)


class RemotePending(object):
    """A class encapsulating a socket and a time of connection."""
    def __init__(self, fd):
        self.fd = fd
        self.birthday = time.time()

    def fileno(self):
        return self.fd.fileno()

    def is_expired(self, timeout):
        return time.time() - self.birthday > timeout

class BufferSocket(object):
    """A class encapsulating a socket and a buffer of data received on it. The
    buffer stores data that has been read to make the socket selectable
    again."""
    def __init__(self, fd):
        self.fd = fd
        self.buf = ""

    def fileno(self):
        return self.fd.fileno()

def listen_socket(addr):
    """Return a nonblocking socket listening on the given address."""
    addrinfo = socket.getaddrinfo(addr[0], addr[1], 0, socket.SOCK_STREAM, socket.IPPROTO_TCP)[0]
    s = socket.socket(addrinfo[0], addrinfo[1], addrinfo[2])
    s.setsockopt(socket.SOL_SOCKET, socket.SO_REUSEADDR, 1)
    s.bind(addr)
    s.listen(10)
    s.setblocking(0)
    return s

# How long to wait for a crossdomain policy request before deciding that this is
# a normal socket.
CROSSDOMAIN_TIMEOUT = 2.0

# Local socket, accepting SOCKS requests from localhost
local_s = listen_socket(options.local_addr)
# Remote socket, accepting both crossdomain policy requests and remote proxy
# connections.
remote_s = listen_socket(options.remote_addr)

# Sockets that may be crossdomain policy requests or may be normal remote
# connections.
crossdomain_pending = []
# Remote connection sockets.
remotes = []
# New local sockets waiting to finish their SOCKS negotiation.
socks_pending = []
# Local Tor sockets, after SOCKS negotiation.
locals = []

# Bidirectional mapping between local sockets and remote sockets.
local_for = {}
remote_for = {}


def handle_policy_request(fd):
    print "handle_policy_request"
    addr = fd.getpeername()
    data = fd.recv(100)
    if data == "<policy-file-request/>\0":
        print "Sending crossdomain policy to %s." % format_addr(addr)
        fd.sendall("""
<cross-domain-policy>
<allow-access-from domain="*" to-ports="%s"/>
</cross-domain-policy>
\0""" % xml.sax.saxutils.escape(str(options.remote_addr[1])))
    elif data == "":
        print "No data from %s." % format_addr(addr)
    else:
        print "Unexpected data from %s." % format_addr(addr)

def grab_string(s, pos):
    """Grab a NUL-terminated string from the given string, starting at the given
    offset. Return (pos, str) tuple, or (pos, None) on error."""
    i = pos
    while i < len(s):
        if s[i] == '\0':
            return (i + 1, s[pos:i])
        i += 1
    return pos, None

def parse_socks_request(data):
    try:
        ver, cmd, dport, o1, o2, o3, o4 = struct.unpack(">BBHBBBB", data[:8])
    except struct.error:
        print "Couldn't unpack SOCKS4 header."
        return None
    if ver != 4:
        print "SOCKS header has wrong version (%d)." % ver
        return None
    if cmd != 1:
        print "SOCKS header had wrong command (%d)." % cmd
        return None
    pos, userid = grab_string(data, 8)
    if userid is None:
        print "Couldn't read userid from SOCKS header."
        return None
    if o1 == 0 and o2 == 0 and o3 == 0 and o4 != 0:
        pos, dest = grab_string(data, pos)
        if dest is None:
            print "Couldn't read destination from SOCKS4a header."
            return None
    else:
        dest = "%d.%d.%d.%d" % (o1, o2, o3, o4)
    return dest, dport

def handle_socks_request(fd):
    print "handle_socks_request"
    addr = fd.getpeername()
    data = fd.recv(100)
    dest_addr = parse_socks_request(data)
    if dest_addr is None:
        # Error reply.
        fd.sendall(struct.pack(">BBHBBBB", 0, 91, 0, 0, 0, 0, 0))
        return False
    print "Got SOCKS request for %s." % format_addr(dest_addr)
    fd.sendall(struct.pack(">BBHBBBB", 0, 90, dest_addr[1], 127, 0, 0, 1))
    # Note we throw away the requested address and port.
    return True

def handle_remote_connection(fd):
    print "handle_remote_connection"
    match_proxies()

def handle_local_connection(fd):
    print "handle_local_connection"
    register()
    match_proxies()

def report_pending():
    print "locals  (%d): %s" % (len(locals), [format_addr(x.fd.getpeername()) for x in locals])
    print "remotes (%d): %s" % (len(remotes), [format_addr(x.getpeername()) for x in remotes])

def register():
    if options.facilitator_addr is None:
        return False
    spec = format_addr((None, options.remote_addr[1]))
    print "Registering \"%s\" with %s." % (spec, format_addr(options.facilitator_addr))
    http = httplib.HTTPConnection(*options.facilitator_addr)
    http.request("POST", "/", urllib.urlencode({"client": spec}))
    http.close()
    return True

def match_proxies():
    while locals and remotes:
        remote = remotes.pop(0)
        local = locals.pop(0)
        remote_addr, remote_port = remote.getpeername()
        local_addr, local_port = local.fd.getpeername()
        print "Linking %s and %s." % (format_addr(local.fd.getpeername()), format_addr(remote.getpeername()))
        if local.buf:
            remote.sendall(local.buf)
        remote_for[local.fd] = remote
        local_for[remote] = local.fd

register()

while True:
    rset = [remote_s, local_s] + crossdomain_pending + socks_pending + remote_for.keys() + local_for.keys() + locals + remotes
    rset, _, _ = select.select(rset, [], [], CROSSDOMAIN_TIMEOUT)
    for fd in rset:
        if fd == remote_s:
            remote_c, addr = fd.accept()
            print "Remote connection from %s." % format_addr(addr)
            crossdomain_pending.append(RemotePending(remote_c))
        elif fd == local_s:
            local_c, addr = fd.accept()
            print "Local connection from %s." % format_addr(addr)
            socks_pending.append(local_c)
            register()
        elif fd in crossdomain_pending:
            print "Data from crossdomain-pending %s." % format_addr(addr)
            handle_policy_request(fd.fd)
            fd.fd.close()
            crossdomain_pending.remove(fd)
        elif fd in socks_pending:
            print "SOCKS request from %s." % format_addr(addr)
            if handle_socks_request(fd):
                locals.append(BufferSocket(fd))
                handle_local_connection(fd)
            else:
                fd.close()
            socks_pending.remove(fd)
            report_pending()
        elif fd in local_for:
            local = local_for[fd]
            data = fd.recv(1024)
            if not data:
                print "EOF from remote %s." % format_addr(fd.getpeername())
                fd.close()
                local.close()
                del local_for[fd]
                del remote_for[local]
                register()
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
        elif fd in locals:
            data = fd.fd.recv(1024)
            if not data:
                print "EOF from unconnected local %s with %d bytes buffered." % (format_addr(fd.fd.getpeername()), len(fd.buf))
                locals.remove(fd)
                fd.fd.close()
            else:
                print "Data from unconnected local %s (%d bytes)." % (format_addr(fd.fd.getpeername()), len(data))
                fd.buf += data
                if len(fd.buf) >= UNCONNECTED_LOCAL_BUFFER_LIMIT:
                    print "Refusing to buffer more than %d bytes from local %s." % (UNCONNECTED_LOCAL_BUFFER_LIMIT, format_addr(fd.fd.getpeername()))
                    locals.remove(fd)
                    fd.fd.close()
            report_pending()
        elif fd in remotes:
            data = fd.recv(1024)
            if not data:
                print "EOF from unconnected remote %s." % format_addr(fd.getpeername())
            else:
                print "Data from unconnected remote %s." % format_addr(fd.getpeername())
            fd.close()
            remotes.remove(fd)
            report_pending()
        match_proxies()
    while crossdomain_pending:
        pending = crossdomain_pending[0]
        if not pending.is_expired(CROSSDOMAIN_TIMEOUT):
            break
        print "Expired pending crossdomain from %s." % format_addr(pending.fd.getpeername())
        crossdomain_pending.pop(0)
        remotes.append(pending.fd)
        handle_remote_connection(pending.fd)
        report_pending()
    sys.stdout.flush()
