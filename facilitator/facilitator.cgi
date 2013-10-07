#!/usr/bin/env python

import cgi
import os
import socket
import sys
import urllib

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

# Send a base64-encoded client address to the registration daemon.
def send_url_reg(reg):
    # Translate from url-safe base64 alphabet to the standard alphabet.
    reg = reg.replace('-', '+').replace('_', '/')
    return fac.put_reg_base64(reg)

method = os.environ.get("REQUEST_METHOD")
remote_addr = (os.environ.get("REMOTE_ADDR"), None)
path_info = os.environ.get("PATH_INFO") or "/"

if not method or not remote_addr[0]:
    exit_error(400)
fs = cgi.FieldStorage()

# Print the HEAD part of a URL-based registration response, or exit with an
# error if appropriate.
def url_reg(reg):
    try:
        if send_url_reg(reg):
            output_status(204)
        else:
            exit_error(400)
    except Exception:
        exit_error(500)

def do_head():
    path_parts = [x for x in path_info.split("/") if x]
    if len(path_parts) == 2 and path_parts[0] == "reg":
        url_reg(path_parts[1])
    else:
        exit_error(400)

def do_get():
    """Parses flashproxy polls.
       Example: GET /?r=1&client=7.1.43.21&client=1.2.3.4&transport=webrtc&transport=websocket
    """

    path_parts = [x for x in path_info.split("/") if x]
    if len(path_parts) == 2 and path_parts[0] == "reg":
        url_reg(path_parts[1])
    elif len(path_parts) == 0:
        # Check for recent enough flash proxy protocol.
        r = fs.getlist("r")
        if len(r) != 1 or r[0] != "1":
            exit_error(400)

        # 'transports' (optional) can be repeated and carries
        # transport names.
        transport_list = fs.getlist("transport")
        if not transport_list:
            transport_list = ["websocket"]

        try:
            reg = fac.get_reg(FACILITATOR_ADDR, remote_addr, transport_list) or ""
        except Exception:
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
    """Parse client registration."""

    # Old style client registration:
    #   client=1.2.3.4:9000
    # New style client registration:
    #   client-websocket=1.2.3.4:9000&client-obfs3|websocket=1.2.3.4:10000

    if path_info != "/":
        exit_error(400)

    # We iterate through the items in the POST body, and see if any of
    # them look like "client-websocket=1.2.3.4:9000". We then split
    # all those items and send them as separate registrations to the
    # facilitator.
    for key in fs.keys():
        if key != "client" and not key.startswith("client-"):
            continue

        if key == "client": # reg without transport info -- default to websocket.
            transport_chain = "websocket"
        else: # reg with transport info -- get the "websocket" part out of "client-websocket".
            transport_chain = key[len("client-"):]

        # Get the "1.2.3.4:9000" part of "client-websocket=1.2.3.4:9000".
        client_spec = fs[key].value.strip()
        try:
            client_addr = fac.parse_addr_spec(client_spec, defhost=remote_addr[0])
        except ValueError:
            exit_error(400)

        # XXX what if previous registrations passed through
        # successfully, but the last one failed and called
        # exit_error()?

        # XXX need to link these registrations together, so that
        # when one is answerered the rest are invalidated.
        if not fac.put_reg(FACILITATOR_ADDR, client_addr, transport_chain, remote_addr):
            exit_error(500)

    print """\
Status: 200\r
\r"""

if method == "HEAD":
    do_head()
elif method == "GET":
    do_get()
elif method == "POST":
    do_post()
else:
    exit_error(405)
