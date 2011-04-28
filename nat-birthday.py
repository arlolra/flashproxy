#!/usr/bin/env python

import fcntl
import getopt
import os
import random
import select
import socket
import sys

def usage(f = sys.stdout):
    print >> f, """\
Usage: %s [-a|-b] [OPTIONS] REMOTE
UDP NAT traversal based on randomly generating port numbers. Run with
-a on one host, then with -b on the other.
  -a       bind to random local ports, connect to static remote port.
  -b       bind to static local port, connect to random remote ports.
  -h       show this help.
  -n N     let N packet be outstanding at once (default %d).
  -p PORT  use PORT as the static port (default %d).\
""" % (sys.argv[0], N, PORT)

MAGIC = "MAGIC_STREAM_START"

SIDE = None
PORT = 2000
N = 500
remote = None
DELAY = 0.1

def unblock(fd):
    flags = fcntl.fcntl(fd, fcntl.F_GETFL)
    fcntl.fcntl(fd, fcntl.F_SETFL, flags | os.O_NONBLOCK)

def main_a(remote):
    ports = set()
    rset = []

    while True:
        for i in range(N):
            while True:
                r = random.randrange(1024, 65536)
                if r not in ports:
                    break
            ports.add(r)
            s = socket.socket(socket.AF_INET, socket.SOCK_DGRAM, socket.IPPROTO_UDP)
            s.bind(("0.0.0.0", r))
            print r
            addr = (remote, PORT)
            s.sendto("hello", 0, addr)
            rset.append(s)
        print "waiting 20 seconds..."
        readable, _, _ = select.select(rset, [], [], 20)
        for fd in readable:
            data, peer = fd.recvfrom(512)
            if data:
                return fd, peer
        while rset:
            rset.pop().close()

def main_b(remote):
    s = socket.socket(socket.AF_INET, socket.SOCK_DGRAM, socket.IPPROTO_UDP)
    s.bind(("0.0.0.0", PORT))

    i = 0
    while True:
        if i >= N:
            readable, _, _ = select.select([s], [], [], DELAY)
            for fd in readable:
                data, peer = fd.recvfrom(512)
                if data:
                    return fd, peer
        else:
            i += 1
        port = random.randrange(1024, 65536)
        addr = (remote, port)
        print addr
        s.sendto("hello", 0, addr)

opts, args = getopt.gnu_getopt(sys.argv[1:], "abhn:p:")
for o, a in opts:
    if o == "-a":
        SIDE = 0
    elif o == "-b":
        SIDE = 1
    elif o == "-h":
        usage()
        sys.exit()
    elif o == "-n":
        N = int(a)
    elif o == "-p":
        PORT = int(a)

try:
    remote_hostname, = args
except ValueError:
    usage(sys.stderr)
    sys.exit(1)

addrinfo = socket.getaddrinfo(remote_hostname, 0, socket.AF_INET, socket.SOCK_DGRAM, socket.IPPROTO_UDP)

if SIDE is None:
    usage(sys.stderr)
    sys.exit(1)
elif SIDE == 0:
    s, peer = main_a(addrinfo[0][4][0])
else:
    s, peer = main_b(addrinfo[0][4][0])

print "got connection", peer

s.sendto(MAGIC, 0, peer)

unblock(sys.stdin)

print "start typing"

while True:
    readable, _, _ = select.select([sys.stdin, s], [], [])
    if sys.stdin in readable:
        data = sys.stdin.read(1024)
        if not data:
            break
        s.sendto(data, 0, peer)
    elif s in readable:
        data = s.recv(1024)
        if not data:
            break
        if data == MAGIC:
            MAGIC = None
        else:
            sys.stdout.write(data)
