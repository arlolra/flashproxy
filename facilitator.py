#!/usr/bin/env python

import BaseHTTPServer
import SocketServer
import getopt
import cgi
import re
import sys
import socket
import time
from collections import deque

DEFAULT_ADDRESS = "0.0.0.0"
DEFAULT_PORT = 9002

LOG_DATE_FORMAT = "%Y-%m-%d %H:%M:%S"

def usage(f = sys.stdout):
    print >> f, """\
Usage: %(progname)s <OPTIONS> [HOST] [PORT]
Flash bridge facilitator: Register client addresses with HTTP POST requests
and serve them out again with HTTP GET. Listen on HOST and PORT, by default
%(addr)s %(port)d.
  -h, --help          show this help.
  -l, --log FILENAME  write log to FILENAME (default stdout).\
""" % {
    "progname": sys.argv[0],
    "addr": DEFAULT_ADDRESS,
    "port": DEFAULT_PORT,
}

log_file = sys.stdout
REGS = deque()

def log(msg):
    print >> log_file, (u"%s %s" % (time.strftime(LOG_DATE_FORMAT), msg)).encode("UTF-8")
    log_file.flush()

class Reg(object):
    def __init__(self, af, host, port):
        self.af = af
        self.host = host
        self.port = port

    def __unicode__(self):
        if self.af == socket.AF_INET6:
            return u"[%s]:%d" % (self.host, self.port)
        else:
            return u"%s:%d" % (self.host, self.port)

    def __str__(self):
        return unicode(self).encode("UTF-8")

    def __cmp__(self, other):
        return cmp((self.af, self.host, self.port), (other.af, other.host, other.port))

    @staticmethod
    def parse(spec, defhost = None, defport = None):
        host = None
        port = None
        m = re.match(r'^\[(.+)\]:(\d*)$', spec)
        if m:
            host, port = m.groups()
            af = socket.AF_INET6
        else:
            m = re.match(r'^(.*):(\d*)$', spec)
            if m:
                host, port = m.groups()
                if host:
                    af = socket.AF_INET
                else:
                    # Has to be guessed from format of defhost.
                    af = 0
        host = host or defhost
        port = port or defport
        if not (host and port):
            raise ValueError("Bad address specification \"%s\"" % spec)

        try:
            addrs = socket.getaddrinfo(host, port, af, socket.SOCK_STREAM, socket.IPPROTO_TCP, socket.AI_NUMERICHOST)
        except socket.gaierror, e:
            raise ValueError("Bad host or port: \"%s\" \"%s\": %s" % (host, port, str(e)))
        if not addrs:
            raise ValueError("Bad host or port: \"%s\" \"%s\"" % (host, port))

        af = addrs[0][0]
        host, port = socket.getnameinfo(addrs[0][4], socket.NI_NUMERICHOST | socket.NI_NUMERICSERV)
        return Reg(af, host, int(port))

def add_reg(reg):
    if reg not in list(REGS):
        REGS.append(reg)
        log("Registration " + str(reg) + " added. Registrations: " + str(len(REGS)))
    else:
        log("Registration " + str(reg) + " already present. Registrations: " + str(len(REGS)))

def fetch_reg():
    """Get a client registration, or None if none is available."""
    if not REGS:
        return None
    return REGS.popleft()

class Handler(BaseHTTPServer.BaseHTTPRequestHandler):
    def do_GET(self):
        line = "From " + str(self.client_address) + " received: GET:"
        reg = fetch_reg()
        if reg:
            line += " Handing out " + str(reg) + ". Clients: " + str(len(REGS))
            self.request.send(str(reg))
        else:
            line += " Registration list is empty"
        log(line)

    def do_POST(self):
        data = self.rfile.readline().strip()
        log("From " + str(self.client_address) + " received: POST: " + data + " :")
        try:
            vals = cgi.parse_qs(data, False, True)
        except ValueError, e:
            log("Syntax error in POST: %s" % str(e))
            return

        client_specs = vals.get("client")
        if client_specs is None or len(client_specs) != 1:
            log("In POST: need exactly one \"client\" param")
            return
        val = client_specs[0]

        try:
            reg = Reg.parse(val, self.client_address[0])
        except ValueError, e:
            log("Can't parse client \"%s\": %s" % (val, str(e)))
            return

        add_reg(reg)

opts, args = getopt.gnu_getopt(sys.argv[1:], "hl:", ["help", "log="])
for o, a in opts:
    if o == "-h" or o == "--help":
        usage()
        sys.exit()
    elif o == "-l" or o == "--log":
        log_file = open(a, "a")

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

class Server(SocketServer.ThreadingMixIn, BaseHTTPServer.HTTPServer):
    pass

# Setup the server
server = Server(address, Handler)

log("Starting Facilitator on " + str(address) + "...")

try:
    server.serve_forever()
except KeyboardInterrupt:
    sys.exit(0)
