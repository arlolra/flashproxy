#!/usr/bin/python

import SocketServer
import sys
from collections import deque

class FaciTCPHandler(SocketServer.BaseRequestHandler):
	client_list = deque()	

	def handle(self):
		self.data = self.request.recv(16).strip();
		print "From %s received:" % str(self.client_address),
		print self.data + " :",
		if(self.data == "GET"):
			if(self.client_list):
				client = self.client_list.popleft()
				print "Handing out " + str(client) + ". Clients: " + str(len(self.client_list))
				reply = client[0] + ':' + str(client[1])
				self.request.send(reply)
			else:
				print "Client list is empty"
				self.request.send("Client list empty")
		elif(self.data == "POST"):
			self.client_list.append(self.client_address)
			print "Appending address to list. Clients: " + str(len(self.client_list))
			self.request.send("Registration successful")
		else:
			print "Bad request"
			self.request.send("Bad request")

HOST = sys.argv[1]
PORT = int(sys.argv[2])

# Setup the server
server = SocketServer.TCPServer((HOST, PORT), FaciTCPHandler)

print "Starting Facilitator on " + str((HOST, PORT)) + "..."

# Run server... Single threaded serving of requests...
server.serve_forever()
