#!/usr/bin/python

import BaseHTTPServer
import cgi
import sys
import socket
from collections import deque

REGS = deque()

class Reg(object):
	def __init__(self, host, port):
		self.host = host
		self.port = port

	def __unicode__(self):
		return u"%s:%d" % (self.host, self.port)

	def __str__(self):
		return unicode(self).encode("UTF-8")

	@staticmethod
	def parse(spec):
		addr, port_s = spec.split(":")

		addr = addr.strip()
		port_s = port_s.strip()

		try:
			socket.inet_aton(addr)
		except socket.error:
			raise ValueError("Bad IP address: \"%s\"" % addr)

		# Additional checks on the IP address, since socket.inet_aton
		# is a little too lax
		if(len(addr.split(".")) != 4):
			raise ValueError("Bad IP address: \"%s\"" % addr)

		try:
			port = int(port_s)
		except ValueError:
			raise ValueError("Bad port number: \"%s\"" % port_s)

		return Reg(addr, port)

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

		REGS.append(reg)
		print "Registration " + str(reg) + " added. Registrations: " + str(len(REGS))

HOST = sys.argv[1]
PORT = int(sys.argv[2])

# Setup the server
server = BaseHTTPServer.HTTPServer((HOST, PORT), Handler)

print "Starting Facilitator on " + str((HOST, PORT)) + "..."

# Run server... Single threaded serving of requests...
server.serve_forever()
