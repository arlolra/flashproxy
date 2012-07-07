#!/usr/bin/env python

import cgi
import sys
import os
import urllib

FACILITATOR_ADDR = ("127.0.0.1", 9002)

def exit_error(status):
    print """\
Status: %d\r
\r""" % status
    sys.exit()

def put_reg(client_addr, registrant_addr):
    # Pretending to register client_addr as reported by registrant_addr.
    pass

def get_reg(proxy_addr):
    # Pretending to ask for a client for the proxy at proxy_addr.
    return {
        "client": "2.2.2.2:2222",
        "relay": "199.1.1.1:9001",
    }

method = os.environ.get("REQUEST_METHOD")
proxy_addr = (os.environ.get("REMOTE_ADDR"), None)

if not method or not proxy_addr[0]:
    exit_error(400)

def do_get():
    try:
        reg = get_reg(proxy_addr) or ""
    except:
        exit_error(500)
    # Allow XMLHttpRequest from any domain. http://www.w3.org/TR/cors/.
    print """\
Status: 200\r
Content-Type: application/x-www-form-urlencoded\r
Cache-Control: no-cache\r
Access-Control-Allow-Origin: *\r
\r"""
    print urllib.urlencode(reg)

if method == "GET":
    do_get()
else:
    exit_error(405)
