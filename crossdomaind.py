#!/usr/bin/env python

# A simple daemon to serve a cross-domain policy.

import socket

ADDRESS = ("0.0.0.0", 843)

POLICY = """\
<cross-domain-policy>
<allow-access-from domain="*" to-ports="*"/>
</cross-domain-policy>
\0"""

s = socket.socket()
s.setsockopt(socket.SOL_SOCKET, socket.SO_REUSEADDR, 1)
s.bind(ADDRESS)
s.listen(10)
while True:
    (c, c_addr) = s.accept()
    c.sendall(POLICY)
    c.close()
