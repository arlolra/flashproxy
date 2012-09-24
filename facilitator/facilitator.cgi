#!/usr/bin/env python

import cgi
import os
import socket
import sys
import urllib

import fac

FACILITATOR_ADDR = ("127.0.0.1", 9002)

def exit_error(status):
    print """\
Status: %d\r
\r""" % status
    sys.exit()

method = os.environ.get("REQUEST_METHOD")
proxy_addr = (os.environ.get("REMOTE_ADDR"), None)
path_info = os.environ.get("PATH_INFO") or "/"

if not method or not proxy_addr[0]:
    exit_error(400)

fs = cgi.FieldStorage()

def do_get():
    if path_info != "/":
        exit_error(400)
    try:
        reg = fac.get_reg(FACILITATOR_ADDR, proxy_addr) or ""
    except:
        exit_error(500)
    # Allow XMLHttpRequest from any domain. http://www.w3.org/TR/cors/.
    print """\
Status: 200\r
Content-Type: application/x-www-form-urlencoded\r
Cache-Control: no-cache\r
Access-Control-Allow-Origin: *\r
\r"""
    sys.stdout.write(urllib.urlencode(reg))

def do_post():
    if path_info != "/":
        exit_error(400)
    client_specs = fs.getlist("client")
    if len(client_specs) != 1:
        exit_error(400)
    client_spec = client_specs[0].strip()
    try:
        client_addr = fac.parse_addr_spec(client_spec, defhost=proxy_addr[0])
    except ValueError:
        exit_error(400)
    if not fac.put_reg(FACILITATOR_ADDR, client_addr, proxy_addr):
        exit_error(500)
    print """\
Status: 200\r
\r"""

if method == "GET":
    do_get()
elif method == "POST":
    do_post()
else:
    exit_error(405)
