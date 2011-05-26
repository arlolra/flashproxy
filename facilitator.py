#!/usr/bin/env python

import BaseHTTPServer
import SocketServer
import cgi
import getopt
import os
import re
import socket
import sys
import threading
import time

DEFAULT_ADDRESS = "0.0.0.0"
DEFAULT_PORT = 9002
DEFAULT_LOG_FILENAME = "facilitator.log"

LOG_DATE_FORMAT = "%Y-%m-%d %H:%M:%S"

class options(object):
    log_filename = DEFAULT_LOG_FILENAME
    log_file = sys.stdout
    daemonize = True

def usage(f = sys.stdout):
    print >> f, """\
Usage: %(progname)s <OPTIONS> [HOST] [PORT]
Flash bridge facilitator: Register client addresses with HTTP POST requests
and serve them out again with HTTP GET. Listen on HOST and PORT, by default
%(addr)s %(port)d.
  -d, --debug         don't daemonize, log to stdout.
  -h, --help          show this help.
  -l, --log FILENAME  write log to FILENAME (default \"%(log)s\").\
""" % {
    "progname": sys.argv[0],
    "addr": DEFAULT_ADDRESS,
    "port": DEFAULT_PORT,
    "log": DEFAULT_LOG_FILENAME,
}

log_lock = threading.Lock()
def log(msg):
    log_lock.acquire()
    try:
        print >> options.log_file, (u"%s %s" % (time.strftime(LOG_DATE_FORMAT), msg)).encode("UTF-8")
        options.log_file.flush()
    finally:
        log_lock.release()

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
    return af, host, int(port)

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

class Reg(object):
    def __init__(self, host, port):
        self.host = host
        self.port = port

    def __unicode__(self):
        return format_addr((self.host, self.port))

    def __str__(self):
        return unicode(self).encode("UTF-8")

    def __cmp__(self, other):
        return cmp((self.host, self.port), (other.host, other.port))

    @staticmethod
    def parse(spec, defhost = None, defport = None):
        af, host, port = parse_addr_spec(spec, defhost, defport)
        try:
            addrs = socket.getaddrinfo(host, port, af, socket.SOCK_STREAM, socket.IPPROTO_TCP, socket.AI_NUMERICHOST)
        except socket.gaierror, e:
            raise ValueError("Bad host or port: \"%s\" \"%s\": %s" % (host, port, str(e)))
        if not addrs:
            raise ValueError("Bad host or port: \"%s\" \"%s\"" % (host, port))

        host, port = socket.getnameinfo(addrs[0][4], socket.NI_NUMERICHOST | socket.NI_NUMERICSERV)
        return Reg(host, int(port))

class RegSet(object):
    def __init__(self):
        self.set = []
        self.cv = threading.Condition()

    def add(self, reg):
        self.cv.acquire()
        try:
            if reg not in list(self.set):
                self.set.append(reg)
                self.cv.notify()
                return True
            else:
                return False
        finally:
            self.cv.release()

    def fetch(self):
        self.cv.acquire()
        try:
            if not self.set:
                return None
            return self.set.pop(0)
        finally:
            self.cv.release()

    def __len__(self):
        self.cv.acquire()
        try:
            return len(self.set)
        finally:
            self.cv.release()

class Handler(BaseHTTPServer.BaseHTTPRequestHandler):
    def do_GET(self):
        log(u"proxy %s connects" % format_addr(self.client_address))

        reg = REGS.fetch()
        if reg:
            log(u"proxy %s gets %s (now %d)" % (format_addr(self.client_address), unicode(reg), len(REGS)))
            self.request.send(str(reg))
        else:
            log(u"proxy %s gets none" % format_addr(self.client_address))

    def do_POST(self):
        data = self.rfile.readline(1024).strip()
        try:
            vals = cgi.parse_qs(data, False, True)
        except ValueError, e:
            log(u"client %s POST syntax error: %s" % (format_addr(self.client_address), repr(str(e))))
            return

        client_specs = vals.get("client")
        if client_specs is None or len(client_specs) != 1:
            log(u"client %s missing \"client\" param" % format_addr(self.client_address))
            return
        val = client_specs[0]

        try:
            reg = Reg.parse(val, self.client_address[0])
        except ValueError, e:
            log(u"client %s syntax error in %s: %s" % (format_addr(self.client_address), repr(val), repr(str(e))))
            return

        log(u"client %s regs %s -> %s" % (format_addr(self.client_address), val, unicode(reg)))
        if REGS.add(reg):
            log(u"client %s %s (now %d)" % (format_addr(self.client_address), unicode(reg), len(REGS)))
        else:
            log(u"client %s %s (already present, now %d)" % (format_addr(self.client_address), unicode(reg), len(REGS)))

    def log_message(self, format, *args):
        msg = format % args
        log(u"message from HTTP handler for %s: %s" % (format_addr(self.client_address), repr(msg)))

REGS = RegSet()

opts, args = getopt.gnu_getopt(sys.argv[1:], "dhl:", ["debug", "help", "log="])
for o, a in opts:
    if o == "-d" or o == "--debug":
        options.daemonize = False
        options.log_filename = None
    elif o == "-h" or o == "--help":
        usage()
        sys.exit()
    elif o == "-l" or o == "--log":
        options.log_filename = a

if options.log_filename:
    options.log_file = open(options.log_filename, "a")
else:
    options.log_file = sys.stdout

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

log(u"start on %s" % format_addr(address))

if options.daemonize:
    log(u"daemonizing")
    if os.fork() != 0:
        sys.exit(0)

try:
    server.serve_forever()
except KeyboardInterrupt:
    sys.exit(0)
