#!/usr/bin/python

import BaseHTTPServer
import cgi
import sys
import socket
from collections import deque

class Handler(BaseHTTPServer.BaseHTTPRequestHandler):
	client_list = deque()	

	def do_GET(self):
		print "From " + str(self.client_address) + " received: GET:",
		if(self.client_list):
			client = self.client_list.popleft()
			print "Handing out " + client + ". Clients: " + str(len(self.client_list))
			self.request.send(client)
		else:
			print "Client list is empty"
			self.request.send("Client list empty")
	
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

		if(len(val.split(":")) != 2):
			print "Bad request, expected client=addr:port"
			return

		addr, port = val.split(":")	
		
		addr = addr.strip()
		port = port.strip()	

		try:
			socket.inet_aton(addr)
		except socket.error:
			print "Bad IP address: " + addr
			return

		# Additional checks on the IP address, since socket.inet_aton
		# is a little too lax
		if(len(addr.split(".")) != 4):
			print "Bad IP address: " + addr
			return

		try:
			int(port)
		except:
			print "Bad port number: " + port
			return

		client = addr + ":" + port
		self.client_list.append(client)
		print "Client " + client + " added. Clients: " + str(len(self.client_list))

HOST = sys.argv[1]
PORT = int(sys.argv[2])

# Setup the server
server = BaseHTTPServer.HTTPServer((HOST, PORT), Handler)

print "Starting Facilitator on " + str((HOST, PORT)) + "..."

# Run server... Single threaded serving of requests...
server.serve_forever()
