#!/usr/bin/env python

import getopt
import httplib
import os
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

LOG_DATE_FORMAT = "%Y-%m-%d %H:%M:%S"

class options(object):
    local_addr = None
    remote_addr = None
    facilitator_addr = None

    log_filename = None
    log_file = sys.stdout
    daemonize = False

# We accept up to this many bytes from a socket not yet matched with a partner
# before disconnecting it.
UNCONNECTED_BUFFER_LIMIT = 10240

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
  --daemon                       daemonize (Unix only).
  -f, --facilitator=HOST[:PORT]  advertise willingness to receive connections to
                                   HOST:PORT. By default PORT is %(fac_port)d.
  -h, --help                     show this help.
  -l, --log FILENAME             write log to FILENAME (default stdout).\
""" % {
    "progname": sys.argv[0],
    "local": format_addr((DEFAULT_LOCAL_ADDRESS, DEFAULT_LOCAL_PORT)),
    "remote": format_addr((DEFAULT_REMOTE_ADDRESS, DEFAULT_REMOTE_PORT)),
    "fac_port": DEFAULT_FACILITATOR_PORT,
}

def log(msg):
    print >> options.log_file, (u"%s %s" % (time.strftime(LOG_DATE_FORMAT), msg)).encode("UTF-8")
    options.log_file.flush()

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

opts, args = getopt.gnu_getopt(sys.argv[1:], "f:hl:", ["daemon", "facilitator=", "help", "log="])
for o, a in opts:
    if o == "--daemon":
        options.daemonize = True
    elif o == "-f" or o == "--facilitator":
        options.facilitator_addr = parse_addr_spec(a, None, DEFAULT_FACILITATOR_PORT)
    elif o == "-h" or o == "--help":
        usage()
        sys.exit()
    elif o == "-l" or o == "--log":
        options.log_filename = a

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

if options.log_filename:
    options.log_file = open(options.log_filename, "a")
else:
    options.log_file = sys.stdout


class BufferSocket(object):
    """A socket containing a time of creation and a buffer of data received. The
    buffer stores data to make the socket selectable again."""
    def __init__(self, fd):
        self.fd = fd
        self.birthday = time.time()
        self.buf = ""

    def __getattr__(self, name):
        return getattr(self.fd, name)

    def is_expired(self, timeout):
        return time.time() - self.birthday > timeout

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
    """Returns True iff the socket is still open and usable (wasn't a
    crossdomain request and wasn't closed."""
    log(u"handle_policy_request")
    addr = fd.getpeername()
    data = fd.recv(100)
    if data == "<policy-file-request/>\0":
        log(u"Sending crossdomain policy to %s." % format_addr(addr))
        fd.sendall("""
<cross-domain-policy>
<allow-access-from domain="*" to-ports="%s"/>
</cross-domain-policy>
\0""" % xml.sax.saxutils.escape(str(options.remote_addr[1])))
        return False
    elif data == "":
        log(u"No data from %s." % format_addr(addr))
        return False
    else:
        fd.buf += data
        return True

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
        log(u"Couldn't unpack SOCKS4 header.")
        return None
    if ver != 4:
        log(u"SOCKS header has wrong version (%d)." % ver)
        return None
    if cmd != 1:
        log(u"SOCKS header had wrong command (%d)." % cmd)
        return None
    pos, userid = grab_string(data, 8)
    if userid is None:
        log(u"Couldn't read userid from SOCKS header.")
        return None
    if o1 == 0 and o2 == 0 and o3 == 0 and o4 != 0:
        pos, dest = grab_string(data, pos)
        if dest is None:
            log(u"Couldn't read destination from SOCKS4a header.")
            return None
    else:
        dest = "%d.%d.%d.%d" % (o1, o2, o3, o4)
    return dest, dport

def handle_socks_request(fd):
    log(u"handle_socks_request")
    addr = fd.getpeername()
    data = fd.recv(100)
    dest_addr = parse_socks_request(data)
    if dest_addr is None:
        # Error reply.
        fd.sendall(struct.pack(">BBHBBBB", 0, 91, 0, 0, 0, 0, 0))
        return False
    log(u"Got SOCKS request for %s." % format_addr(dest_addr))
    fd.sendall(struct.pack(">BBHBBBB", 0, 90, dest_addr[1], 127, 0, 0, 1))
    # Note we throw away the requested address and port.
    return True

def handle_remote_connection(fd):
    log(u"handle_remote_connection")
    match_proxies()

def handle_local_connection(fd):
    log(u"handle_local_connection")
    register()
    match_proxies()

def report_pending():
    log(u"locals  (%d): %s" % (len(locals), [format_addr(x.getpeername()) for x in locals]))
    log(u"remotes (%d): %s" % (len(remotes), [format_addr(x.getpeername()) for x in remotes]))

def register():
    if options.facilitator_addr is None:
        return False
    spec = format_addr((None, options.remote_addr[1]))
    log(u"Registering \"%s\" with %s." % (spec, format_addr(options.facilitator_addr)))
    http = httplib.HTTPConnection(*options.facilitator_addr)
    http.request("POST", "/", urllib.urlencode({"client": spec}))
    http.close()
    return True

def proxy_chunk(fd_r, fd_w, label):
    try:
        data = fd_r.recv(1024)
    except socket.error, e: # Can be "Connection reset by peer".
        log(u"Socket error from %s: %s" % (label, repr(str(e))))
        fd_w.close()
        return False
    if not data:
        log(u"EOF from %s %s." % (label, format_addr(fd_r.getpeername())))
        fd_r.close()
        fd_w.close()
        return False
    else:
        fd_w.sendall(data)
        return True

def match_proxies():
    while locals and remotes:
        remote = remotes.pop(0)
        local = locals.pop(0)
        remote_addr, remote_port = remote.getpeername()
        local_addr, local_port = local.getpeername()
        log(u"Linking %s and %s." % (format_addr(local.getpeername()), format_addr(remote.getpeername())))
        if local.buf:
            remote.sendall(local.buf)
        if remote.buf:
            local.sendall(remote.buf)
        remote_for[local.fd] = remote.fd
        local_for[remote.fd] = local.fd

if options.daemonize:
    log(u"Daemonizing.")
    if os.fork() != 0:
        sys.exit(0)

register()

while True:
    rset = [remote_s, local_s] + crossdomain_pending + socks_pending + remote_for.keys() + local_for.keys() + locals + remotes
    rset, _, _ = select.select(rset, [], [], CROSSDOMAIN_TIMEOUT)
    for fd in rset:
        if fd == remote_s:
            remote_c, addr = fd.accept()
            log(u"Remote connection from %s." % format_addr(addr))
            crossdomain_pending.append(BufferSocket(remote_c))
        elif fd == local_s:
            local_c, addr = fd.accept()
            log(u"Local connection from %s." % format_addr(addr))
            socks_pending.append(local_c)
            register()
        elif fd in crossdomain_pending:
            log(u"Data from crossdomain-pending %s." % format_addr(addr))
            if handle_policy_request(fd):
                remotes.append(fd)
                handle_remote_connection(fd)
            else:
                fd.close()
            crossdomain_pending.remove(fd)
            report_pending()
        elif fd in socks_pending:
            log(u"SOCKS request from %s." % format_addr(addr))
            if handle_socks_request(fd):
                locals.append(BufferSocket(fd))
                handle_local_connection(fd)
            else:
                fd.close()
            socks_pending.remove(fd)
            report_pending()
        elif fd in local_for:
            local = local_for[fd]
            if not proxy_chunk(fd, local, "remote"):
                del local_for[fd]
                del remote_for[local]
                register()
        elif fd in remote_for:
            remote = remote_for[fd]
            if not proxy_chunk(fd, remote, "local"):
                del remote_for[fd]
                del local_for[remote]
                register()
        elif fd in locals:
            data = fd.recv(1024)
            if not data:
                log(u"EOF from unconnected local %s with %d bytes buffered." % (format_addr(fd.getpeername()), len(fd.buf)))
                locals.remove(fd)
                fd.close()
            else:
                log(u"Data from unconnected local %s (%d bytes)." % (format_addr(fd.getpeername()), len(data)))
                fd.buf += data
                if len(fd.buf) >= UNCONNECTED_BUFFER_LIMIT:
                    log(u"Refusing to buffer more than %d bytes from local %s." % (UNCONNECTED_BUFFER_LIMIT, format_addr(fd.getpeername())))
                    locals.remove(fd)
                    fd.close()
            report_pending()
        elif fd in remotes:
            data = fd.recv(1024)
            if not data:
                log(u"EOF from unconnected remote %s with %d bytes buffered." % (format_addr(fd.getpeername()), len(fd.buf)))
                remotes.remove(fd)
                fd.close()
            else:
                log(u"Data from unconnected remote %s (%d bytes)." % format_addr(fd.getpeername()), len(data))
                fd.buf += data
                if len(fd.buf) >= UNCONNECTED_BUFFER_LIMIT:
                    log(u"Refusing to buffer more than %d bytes from local %s." % (UNCONNECTED_BUFFER_LIMIT, format_addr(fd.getpeername())))
                    remotes.remove(fd)
                    fd.close()
            report_pending()
        match_proxies()
    while crossdomain_pending:
        pending = crossdomain_pending[0]
        if not pending.is_expired(CROSSDOMAIN_TIMEOUT):
            break
        log(u"Expired pending crossdomain from %s." % format_addr(pending.getpeername()))
        crossdomain_pending.pop(0)
        remotes.append(pending)
        handle_remote_connection(pending)
        report_pending()
