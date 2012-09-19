#!/usr/bin/env python

import cgi
import os
import os.path
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

def fac_socket():
    return socket.create_connection(FACILITATOR_ADDR, 1.0).makefile()

def transact(f, command, *params):
    transaction = fac.render_transaction(command, *params)
    print >> f, transaction
    f.flush()
    line = f.readline()
    if not (len(line) > 0 and line[-1] == '\n'):
        raise ValueError("No newline at end of string returned by facilitator")
    return fac.parse_transaction(line[:-1])

def put_reg(client_addr, registrant_addr):
    f = fac_socket()
    try:
        command, params = transact(f, "PUT", ("CLIENT", fac.format_addr(client_addr)), ("FROM", fac.format_addr(registrant_addr)))
    finally:
        f.close()
    if command == "OK":
        pass
    else:
        exit_error(500)

def get_reg(proxy_addr):
    f = fac_socket()
    try:
        command, params = transact(f, "GET", ("FROM", fac.format_addr(proxy_addr)))
    finally:
        f.close()
    if command == "NONE":
        return {
            "client": ""
        }
    elif command == "OK":
        client_spec = fac.param_first("CLIENT", params)
        relay_spec = fac.param_first("RELAY", params)
        if not client_spec or not relay_spec:
            exit_error(500)
        try:
            # Check the syntax returned by the backend.
            client = fac.parse_addr_spec(client_spec)
            relay = fac.parse_addr_spec(relay_spec)
        except ValueError:
            exit_error(500)
        return {
            "client": fac.format_addr(client),
            "relay": fac.format_addr(relay),
        }
    else:
        exit_error(500)

method = os.environ.get("REQUEST_METHOD")
path_info = os.environ.get("PATH_INFO")
proxy_addr = (os.environ.get("REMOTE_ADDR"), None)

if not method or not path_info or not proxy_addr[0]:
    exit_error(400)

path = os.path.normpath(path_info)

fs = cgi.FieldStorage()

def do_get():
    if path != "/":
        exit_error(400)
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
    sys.stdout.write(urllib.urlencode(reg))

def do_post():
    if path != "/":
        exit_error(400)
    client_specs = fs.getlist("client")
    if len(client_specs) != 1:
        exit_error(400)
    client_spec = client_specs[0].strip()
    try:
        client_addr = fac.parse_addr_spec(client_spec, defhost=proxy_addr[0])
    except ValueError:
        exit_error(400)
    try:
        put_reg(client_addr, proxy_addr)
    except:
        raise
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
