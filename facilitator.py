#!/usr/bin/python

import BaseHTTPServer
import cgi
import re
import sys
import socket
from collections import deque

REGS = deque()

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
	def parse(spec):
		m = re.match(r'^\[(.*)\]:(\d+)$', spec)
		if m:
			host, port = m.groups()
			af = socket.AF_INET6
		else:
			m = re.match(r'^(.*):(\d+)$', spec)
			if m:
				host, port = m.groups()
				af = socket.AF_INET
			else:
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

def fetch_reg():
	"""Get a client registration, or None if none is available."""
	if not REGS:
		return None
	return REGS.popleft()

class Handler(BaseHTTPServer.BaseHTTPRequestHandler):
	def do_GET(self):
		print "From " + str(self.client_address) + " received: GET:",
		reg = fetch_reg()
		if reg:
			print "Handing out " + str(reg) + ". Clients: " + str(len(REGS))
			self.request.send(str(reg))
		else:
			print "Registration list is empty"
			self.request.send("Registration list empty")

	def do_POST(self):
		print "From " + str(self.client_address) + " received: POST:",
		data = self.rfile.readline().strip()
		print data + " :",
		try:
			vals = cgi.parse_qs(data, False, True)
		except ValueError, e:
			print "Syntax error in POST:", str(e)
			return

		client_specs = vals.get("client")
		if client_specs is None or len(client_specs) != 1:
			print "In POST: need exactly one \"client\" param"
			return
		val = client_specs[0]

		try:
			reg = Reg.parse(val)
		except ValueError, e:
			print "Can't parse client \"%s\": %s" % (val, str(e))
			return

		if reg not in list(REGS):
			REGS.append(reg)
			print "Registration " + str(reg) + " added. Registrations: " + str(len(REGS))
		else:
			print "Registration " + str(reg) + " already present. Registrations: " + str(len(REGS))

HOST = sys.argv[1]
PORT = int(sys.argv[2])

# Setup the server
server = BaseHTTPServer.HTTPServer((HOST, PORT), Handler)

print "Starting Facilitator on " + str((HOST, PORT)) + "..."

# Run server... Single threaded serving of requests...
server.serve_forever()
