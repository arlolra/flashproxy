#!/usr/bin/env python

import httplib
import select
import socket
import urllib

PROXY_LISTEN_ADDRESS = ("0.0.0.0", 9000)
TOR_LISTEN_ADDRESS = ("0.0.0.0", 9001)
FACILITATOR_ADDR_SPEC = "localhost:9002"
CLIENT_ADDR_SPEC = "192.168.0.2:9000"

proxy_s = socket.socket()
proxy_s.setsockopt(socket.SOL_SOCKET, socket.SO_REUSEADDR, 1)
proxy_s.bind(PROXY_LISTEN_ADDRESS)
proxy_s.listen(10)
proxy_s.setblocking(0)

tor_s = socket.socket()
tor_s.setsockopt(socket.SOL_SOCKET, socket.SO_REUSEADDR, 1)
tor_s.bind(TOR_LISTEN_ADDRESS)
tor_s.listen(10)
tor_s.setblocking(0)

proxy_pool = []
tor_pool = []

proxy_for = {}
tor_for = {}

def register():
    http = httplib.HTTPConnection(FACILITATOR_ADDR_SPEC)
    http.request("POST", "/", urllib.urlencode({"client": CLIENT_ADDR_SPEC}))
    http.close()

def match_proxies():
    while proxy_pool and tor_pool:
        proxy = proxy_pool.pop(0)
        tor = tor_pool.pop(0)
        proxy_addr, proxy_port = proxy.getpeername()
        tor_addr, tor_port = tor.getpeername()
        print "Linking %s:%d and %s:%d." % (proxy_addr, proxy_port, tor_addr, tor_port)
        proxy_for[tor] = proxy
        tor_for[proxy] = tor

register()

while True:
    rset = [proxy_s, tor_s] + proxy_for.keys() + tor_for.keys()
    rset, _, _ = select.select(rset, [], [])
    for fd in rset:
        if fd == proxy_s:
            proxy_c, addr = fd.accept()
            print "Proxy connection from %s:%d." % addr
            proxy_pool.append(proxy_c)
        elif fd == tor_s:
            tor_c, addr = fd.accept()
            print "Tor connection from %s:%d." % addr
            tor_pool.append(tor_c)
        elif fd in tor_for:
            tor = tor_for[fd]
            data = fd.recv(1024)
            if not data:
                print "EOF from proxy %s:%d." % fd.getpeername()
                fd.close()
                tor.close()
                del tor_for[fd]
                del proxy_for[tor]
            else:
                tor.sendall(data)
        elif fd in proxy_for:
            proxy = proxy_for[fd]
            data = fd.recv(1024)
            if not data:
                print "EOF from Tor %s:%d." % fd.getpeername()
                fd.close()
                proxy.close()
                del proxy_for[fd]
                del tor_for[proxy]
            else:
                proxy.sendall(data)
        match_proxies()
