#!/usr/bin/env python

import cgi
import os
import socket
import sys
import urllib
import subprocess

import fac

FACILITATOR_ADDR = ("127.0.0.1", 9002)
FACILITATOR_REG_URL_ADDR = ("127.0.0.1", 9003)

def output_status(status):
    print """\
Status: %d\r
\r""" % status

def exit_error(status):
    output_status(status)
    sys.exit()

# Send a client registration to the helper daemon,
# which handles decryption and registration.
def url_reg(reg):
    sock = socket.create_connection(FACILITATOR_REG_URL_ADDR)
    sock.sendall(reg)
    sock.shutdown(socket.SHUT_WR)
    response = sock.recv(4096)
    sock.close()
    if response == "\x00":
        return True
    else:
        return False

method = os.environ.get("REQUEST_METHOD")
remote_addr = (os.environ.get("REMOTE_ADDR"), None)
path_info = os.environ.get("PATH_INFO") or "/"

if not method or not remote_addr[0]:
    exit_error(400)

fs = cgi.FieldStorage()

def do_get():
    args = [arg for arg in path_info.split("/") if arg]
    # Check if we have a URL registration or a request for a client.
    if len(args) == 2:
        if args[0] != "reg":
            exit_error(400)
        reg = args[1]
        if not url_reg(reg):
            exit_error(500)
        print """\
Status: 200\r
\r"""
    elif len(args) == 0:
        try:
            reg = fac.get_reg(FACILITATOR_ADDR, remote_addr) or ""
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
    else:
        exit_error(400)

def do_post():
    if path_info != "/":
        exit_error(400)
    client_specs = fs.getlist("client")
    if len(client_specs) != 1:
        exit_error(400)
    client_spec = client_specs[0].strip()
    try:
        client_addr = fac.parse_addr_spec(client_spec, defhost=remote_addr[0])
    except ValueError:
        exit_error(400)
    if not fac.put_reg(FACILITATOR_ADDR, client_addr, remote_addr):
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
