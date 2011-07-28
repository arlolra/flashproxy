#!/usr/bin/env python

import BaseHTTPServer
import SocketServer
import cgi
import errno
import getopt
import os
import re
import socket
import sys
import threading
import time
import urllib
import urlparse

DEFAULT_ADDRESS = "0.0.0.0"
DEFAULT_PORT = 9002
DEFAULT_RELAY_PORT = 9001
DEFAULT_LOG_FILENAME = "facilitator.log"

LOG_DATE_FORMAT = "%Y-%m-%d %H:%M:%S"

class options(object):
    log_filename = DEFAULT_LOG_FILENAME
    log_file = sys.stdout
    relay_spec = None
    daemonize = True

    @staticmethod
    def set_relay_spec(spec):
        af, host, port = parse_addr_spec(spec, defport = DEFAULT_RELAY_PORT)
        # Resolve to get an IP address.
        addrs = socket.getaddrinfo(host, port, af)
        options.relay_spec = format_addr(addrs[0][4])

def usage(f = sys.stdout):
    print >> f, """\
Usage: %(progname)s -r RELAY <OPTIONS> [HOST] [PORT]
Flash bridge facilitator: Register client addresses with HTTP POST requests
and serve them out again with HTTP GET. Listen on HOST and PORT, by default
%(addr)s %(port)d.
  -d, --debug         don't daemonize, log to stdout.
  -h, --help          show this help.
  -l, --log FILENAME  write log to FILENAME (default \"%(log)s\").
  -r, --relay RELAY   send RELAY (host:port) to proxies as the relay to use.\
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

class TCPReg(object):
    def __init__(self, host, port):
        self.host = host
        self.port = port

    def __unicode__(self):
        return format_addr((self.host, self.port))

    def __str__(self):
        return unicode(self).encode("UTF-8")

    def __cmp__(self, other):
        if isinstance(other, TCPReg):
            return cmp((self.host, self.port), (other.host, other.port))
        else:
            return False

class RTMFPReg(object):
    def __init__(self, id):
        self.id = id

    def __unicode__(self):
        return u"%s" % self.id

    def __str__(self):
        return unicode(self).encode("UTF-8")

    def __cmp__(self, other):
        if isinstance(other, RTMFPReg):
            return cmp(self.id, other.id)
        else:
            return False

class Reg(object):
    @staticmethod
    def parse(spec, defhost = None, defport = None):
        try:
            af, host, port = parse_addr_spec(spec, defhost, defport)
        except ValueError:
            pass
        else:
            try:
                addrs = socket.getaddrinfo(host, port, af, socket.SOCK_STREAM, socket.IPPROTO_TCP, socket.AI_NUMERICHOST)
            except socket.gaierror, e:
                raise ValueError("Bad host or port: \"%s\" \"%s\": %s" % (host, port, str(e)))
            if not addrs:
                raise ValueError("Bad host or port: \"%s\" \"%s\"" % (host, port))

            host, port = socket.getnameinfo(addrs[0][4], socket.NI_NUMERICHOST | socket.NI_NUMERICSERV)
            return TCPReg(host, int(port))

        if re.match(ur'^[0-9A-Fa-f]{64}$', spec):
            return RTMFPReg(spec)

        raise ValueError("Bad spec format: %s" % repr(spec))

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
        proxy_addr_s = format_addr(self.client_address)

        log(u"proxy %s connects" % proxy_addr_s)

        path = urlparse.urlsplit(self.path)[2]

        if path == u"/crossdomain.xml":
            self.send_crossdomain()
            return

        reg = REGS.fetch()
        if reg:
            log(u"proxy %s gets %s, relay %s (now %d)" %
                (proxy_addr_s, unicode(reg), options.relay_spec, len(REGS)))
            self.send_client(reg)
        else:
            log(u"proxy %s gets none" % proxy_addr_s)
            self.send_client(None)

    def do_POST(self):
        client_addr_s = format_addr(self.client_address)

        data = cgi.FieldStorage(fp = self.rfile, headers = self.headers,
            environ = {"REQUEST_METHOD": "POST"})

        client_spec = data.getfirst("client")
        if client_spec is None:
            log(u"client %s missing \"client\" param" % client_addr_s)
            self.send_error(400)
            return

        try:
            reg = Reg.parse(client_spec, self.client_address[0])
        except ValueError, e:
            log(u"client %s syntax error in %s: %s"
                % (client_addr_s, repr(client_spec), repr(str(e))))
            self.send_error(400)
            return

        log(u"client %s regs %s -> %s"
            % (client_addr_s, repr(client_spec), unicode(reg)))
        if REGS.add(reg):
            log(u"client %s %s (now %d)"
                % (client_addr_s, unicode(reg), len(REGS)))
        else:
            log(u"client %s %s (already present, now %d)"
                % (client_addr_s, unicode(reg), len(REGS)))

        self.send_response(200)
        self.end_headers()

    def send_crossdomain(self):
        crossdomain = """\
<cross-domain-policy>
<allow-access-from domain="*"/>
</cross-domain-policy>
"""
        self.send_response(200)
        # Content-Type must be one of a few whitelisted types.
        # http://www.adobe.com/devnet/flashplayer/articles/fplayer9_security.html#_Content-Type_Whitelist
        self.send_header("Content-Type", "application/xml")
        self.end_headers()
        self.wfile.write(crossdomain)

    def send_error(self, code, message = None):
        self.send_response(code)
        self.end_headers()
        if message:
            self.wfile.write(message)

    def log_request(self, code):
        addr_s = format_addr(self.client_address)
        try:
            referer = self.headers["Referer"]
        except (AttributeError, KeyError):
            referer = "-"
        log(u"resp %s %s %d %s"
            % (addr_s, repr(self.requestline), code, repr(referer)))

    def log_message(self, format, *args):
        msg = format % args
        log(u"message from HTTP handler for %s: %s"
            % (format_addr(self.client_address), repr(msg)))

    def send_client(self, reg):
        if reg:
            client_str = str(reg)
        else:
            # Send an empty string rather than a 404 or similar because Flash
            # Player's URLLoader can't always distinguish a 404 from, say,
            # "server not found."
            client_str = ""
        self.send_response(200)
        self.send_header("Content-Type", "x-www-form-urlencoded")
        self.send_header("Cache-Control", "no-cache")
        self.end_headers()

        data = {}
        data["client"] = client_str
        data["relay"] = options.relay_spec
        self.request.send(urllib.urlencode(data))

    # Catch "broken pipe" errors that otherwise cause a stack trace in the log.
    def catch_epipe(fn):
        def ret(self, *args):
            try:
                fn(self, *args)
            except socket.error, e:
                if e.errno != errno.EPIPE:
                    raise
                log(u"%s broken pipe" % format_addr(self.client_address))
        return ret
    handle = catch_epipe(BaseHTTPServer.BaseHTTPRequestHandler.handle)
    finish = catch_epipe(BaseHTTPServer.BaseHTTPRequestHandler.finish)

REGS = RegSet()

opts, args = getopt.gnu_getopt(sys.argv[1:], "dhl:r:",
    ["debug", "help", "log=", "relay="])
for o, a in opts:
    if o == "-d" or o == "--debug":
        options.daemonize = False
        options.log_filename = None
    elif o == "-h" or o == "--help":
        usage()
        sys.exit()
    elif o == "-l" or o == "--log":
        options.log_filename = a
    elif o == "-r" or o == "--relay":
        try:
            options.set_relay_spec(a)
        except socket.gaierror, e:
            print >> sys.stderr, u"Can't resolve relay %s: %s" % (repr(a), str(e))
            sys.exit(1)

if options.log_filename:
    options.log_file = open(options.log_filename, "a")
else:
    options.log_file = sys.stdout

if not options.relay_spec:
    print >> sys.stderr, """\
The -r option is required. Give it the relay that will be sent to proxies.
  -r HOST[:PORT]\
"""
    sys.exit(1)

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

class Server(SocketServer.ThreadingMixIn, BaseHTTPServer.HTTPServer):
    pass

# Setup the server
server = Server(addrinfo[4], Handler)

log(u"start on %s" % format_addr(addrinfo[4]))
log(u"using relay address %s" % options.relay_spec)

if options.daemonize:
    log(u"daemonizing")
    if os.fork() != 0:
        sys.exit(0)

try:
    server.serve_forever()
except KeyboardInterrupt:
    sys.exit(0)
