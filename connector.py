#!/usr/bin/env python

import array
import base64
import cStringIO
import getopt
import hashlib
import httplib
import os
import re
import select
import socket
import struct
import subprocess
import sys
import time
import traceback
import urllib
import xml.sax.saxutils
import BaseHTTPServer

DEFAULT_REMOTE_ADDRESS = "0.0.0.0"
DEFAULT_REMOTE_PORT = 9000
DEFAULT_LOCAL_ADDRESS = "127.0.0.1"
DEFAULT_LOCAL_PORT = 9001

LOG_DATE_FORMAT = "%Y-%m-%d %H:%M:%S"

class options(object):
    local_addr = None
    remote_addr = None
    facilitator_addr = None

    log_filename = None
    log_file = sys.stdout
    daemonize = False
    register = False
    pid_filename = None

# We accept up to this many bytes from a socket not yet matched with a partner
# before disconnecting it.
UNCONNECTED_BUFFER_LIMIT = 10240

def usage(f = sys.stdout):
    print >> f, """\
Usage: %(progname)s --register [LOCAL][:PORT] [REMOTE][:PORT]
Wait for connections on a local and a remote port. When any pair of connections
exists, data is ferried between them until one side is closed. By default
LOCAL is "%(local)s" and REMOTE is "%(remote)s".

The local connection acts as a SOCKS4a proxy, but the host and port in the SOCKS
request are ignored and the local connection is always linked to a remote
connection.

If the --register option is used, then your IP address will be sent to the
facilitator so that proxies can connect to you. You need to register in some way
in order to get any service. The --facilitator option allows controlling which
facilitator is used; if omitted, it uses a public default.
  --daemon                       daemonize (Unix only).
  -f, --facilitator=HOST[:PORT]  advertise willingness to receive connections to
                                   HOST:PORT.
  -h, --help                     show this help.
  -l, --log FILENAME             write log to FILENAME (default stdout).
      --pidfile FILENAME         write PID to FILENAME after daemonizing.
  -r, --register                 register with the facilitator.\
""" % {
    "progname": sys.argv[0],
    "local": format_addr((DEFAULT_LOCAL_ADDRESS, DEFAULT_LOCAL_PORT)),
    "remote": format_addr((DEFAULT_REMOTE_ADDRESS, DEFAULT_REMOTE_PORT)),
}

def log(msg):
    print >> options.log_file, (u"%s %s" % (time.strftime(LOG_DATE_FORMAT), msg)).encode("UTF-8")
    options.log_file.flush()

def parse_addr_spec(spec, defhost = None, defport = None):
    host = None
    port = None
    m = None
    # IPv6 syntax.
    if not m:
        m = re.match(ur'^\[(.+)\]:(\d+)$', spec)
        if m:
            host, port = m.groups()
            af = socket.AF_INET6
    if not m:
        m = re.match(ur'^\[(.+)\]:?$', spec)
        if m:
            host, = m.groups()
            af = socket.AF_INET6
    # IPv4 syntax.
    if not m:
        m = re.match(ur'^(.+):(\d+)$', spec)
        if m:
            host, port = m.groups()
            af = socket.AF_INET
    if not m:
        m = re.match(ur'^:?(\d+)$', spec)
        if m:
            port, = m.groups()
            af = 0
    if not m:
        host = spec
        af = 0
    host = host or defhost
    port = port or defport
    if not (host and port):
        raise ValueError("Bad address specification \"%s\"" % spec)
    return host, int(port)

def format_addr(addr):
    host, port = addr
    if not host:
        return u":%d" % port
    # Numeric IPv6 address?
    try:
        addrs = socket.getaddrinfo(host, port, 0, socket.SOCK_STREAM, socket.IPPROTO_TCP, socket.AI_NUMERICHOST)
        af = addrs[0][0]
    except socket.gaierror, e:
        af = 0
    if af == socket.AF_INET6:
        return u"[%s]:%d" % (host, port)
    else:
        return u"%s:%d" % (host, port)



def apply_mask(payload, mask_key):
    result = array.array("B", payload)
    m = array.array("B", mask_key)
    i = 0
    while i < len(result) - 7:
        result[i] ^= m[0]
        result[i+1] ^= m[1]
        result[i+2] ^= m[2]
        result[i+3] ^= m[3]
        result[i+4] ^= m[0]
        result[i+5] ^= m[1]
        result[i+6] ^= m[2]
        result[i+7] ^= m[3]
        i += 8
    while i < len(result):
        result[i] ^= m[i%4]
        i += 1
    return result.tostring()

class WebSocketFrame(object):
    def __init__(self):
        self.fin = False
        self.opcode = None
        self.payload = None

    def is_control(self):
        return (self.opcode & 0x08) != 0

class WebSocketMessage(object):
    def __init__(self):
        self.opcode = None
        self.payload = None

    def is_control(self):
        return (self.opcode & 0x08) != 0

class WebSocketDecoder(object):
    """RFC 6455 section 5 is about the WebSocket framing format."""
    # Raise an exception rather than buffer anything larger than this.
    MAX_MESSAGE_LENGTH = 1024 * 1024

    class MaskingError(ValueError):
        pass

    def __init__(self, use_mask = False):
        """use_mask should be True for server-to-client sockets, and False for
        client-to-server sockets."""
        self.use_mask = use_mask

        # Per-frame state.
        self.buf = ""

        # Per-message state.
        self.message_buf = ""
        self.message_opcode = None

    def feed(self, data):
        self.buf += data

    def read_frame(self):
        """Read a frame from the internal buffer, if one is available. Returns a
        WebSocketFrame object, or None if there are no complete frames to
        read."""
        # RFC 6255 section 5.2.
        if len(self.buf) < 2:
            return None
        offset = 0
        b0, b1 = struct.unpack_from(">BB", self.buf, offset)
        offset += 2
        fin = (b0 & 0x80) != 0
        opcode = b0 & 0x0f
        frame_masked = (b1 & 0x80) != 0
        payload_len = b1 & 0x7f

        if payload_len == 126:
            if len(self.buf) < offset + 2:
                return None
            payload_len, = struct.unpack_from(">H", self.buf, offset)
            offset += 2
        elif payload_len == 127:
            if len(self.buf) < offset + 8:
                return None
            payload_len, = struct.unpack_from(">Q", self.buf, offset)
            offset += 8

        if frame_masked:
            if not self.use_mask:
                # "A client MUST close a connection if it detects a masked
                # frame."
                raise self.MaskingError("Got masked payload from server")
            if len(self.buf) < offset + 4:
                return None
            mask_key = self.buf[offset:offset+4]
            offset += 4
        else:
            if self.use_mask:
                # "The server MUST close the connection upon receiving a frame
                # that is not masked."
                raise self.MaskingError("Got unmasked payload from client")
            mask_key = None

        if payload_len > self.MAX_MESSAGE_LENGTH:
            raise ValueError("Refusing to buffer payload of %d bytes" % payload_len)

        if len(self.buf) < offset + payload_len:
            return None
        if mask_key:
            payload = apply_mask(self.buf[offset:offset+payload_len], mask_key)
        else:
            payload = self.buf[offset:offset+payload_len]
        self.buf = self.buf[offset+payload_len:]

        frame = WebSocketFrame()
        frame.fin = fin
        frame.opcode = opcode
        frame.payload = payload

        return frame

    def read_message(self):
        """Read a complete message. If the opcode is 1, the payload is decoded
        from a UTF-8 binary string to a unicode string. If a control frame is
        read while another fragmented message is in progress, the control frame
        is returned as a new message immediately. Returns None if there is no
        complete frame to be read."""
        # RFC 6455 section 5.4 is about fragmentation.
        while True:
            frame = self.read_frame()
            if frame is None:
                return None
            # "Control frames (see Section 5.5) MAY be injected in the middle of
            # a fragmented message. Control frames themselves MUST NOT be
            # fragmented."
            if frame.is_control():
                if not frame.fin:
                    raise ValueError("Control frame (opcode %d) has FIN bit clear" % frame.opcode)
                message = WebSocketMessage()
                message.opcode = frame.opcode
                message.payload = frame.payload
                return message

            if self.message_opcode is None:
                if frame.opcode == 0:
                    raise ValueError("First frame has opcode 0")
                self.message_opcode = frame.opcode
            else:
                if frame.opcode != 0:
                    raise ValueError("Non-first frame has nonzero opcode %d" % frame.opcode)
            self.message_buf += frame.payload

            if frame.fin:
                break
        message = WebSocketMessage()
        message.opcode = self.message_opcode
        message.payload = self.message_buf
        self.postprocess_message(message)
        self.message_opcode = None
        self.message_buf = ""

        return message

    def postprocess_message(self, message):
        if message.opcode == 1:
            message.payload = message.payload.decode("utf-8")
        return message

class WebSocketEncoder(object):
    def __init__(self, use_mask = False):
        self.use_mask = use_mask

    def encode_frame(self, opcode, payload):
        if opcode >= 16:
            raise ValueError("Opcode of %d is >= 16" % opcode)
        length = len(payload)

        if self.use_mask:
            mask_key = os.urandom(4)
            payload = apply_mask(payload, mask_key)
            mask_bit = 0x80
        else:
            mask_key = ""
            mask_bit = 0x00

        if length < 126:
            len_b, len_ext = length, ""
        elif length < 0x10000:
            len_b, len_ext = 126, struct.pack(">H", length)
        elif length < 0x10000000000000000:
            len_b, len_ext = 127, struct.pack(">Q", length)
        else:
            raise ValueError("payload length of %d is too long" % length)

        return chr(0x80 | opcode) + chr(mask_bit | len_b) + len_ext + mask_key + payload

    def encode_message(self, opcode, payload):
        if opcode == 1:
            payload = payload.encode("utf-8")
        return self.encode_frame(opcode, payload)

# WebSocket implementations generally support text (opcode 1) messages, which
# are UTF-8-encoded text. Not all support binary (opcode 2) messages. During the
# WebSocket handshake, we use the "base64" value of the Sec-WebSocket-Protocol
# header field to indicate that text frames should encoded UTF-8-encoded
# base64-encoded binary data. Binary messages are always interpreted verbatim,
# but text messages are rejected if "base64" was not negotiated.
#
# The idea here is that browsers that know they don't support binary messages
# can negotiate "base64" with both endpoints and still reliably transport binary
# data. Those that know they can support binary messages can just use binary
# messages in the straightforward way.

class WebSocketBinaryDecoder(object):
    def __init__(self, protocols, use_mask = False):
        self.dec = WebSocketDecoder(use_mask)
        self.base64 = "base64" in protocols

    def feed(self, data):
        self.dec.feed(data)

    def read(self):
        """Returns None when there are currently no data to be read. Returns ""
        when a close message is received."""
        while True:
            message = self.dec.read_message()
            if message is None:
                return None
            elif message.opcode == 1:
                if not self.base64:
                    raise ValueError("Received text message on decoder incapable of base64")
                payload = base64.b64decode(message.payload)
                if payload:
                    return payload
            elif message.opcode == 2:
                if message.payload:
                    return message.payload
            elif message.opcode == 8:
                return ""
            # Ignore all other opcodes.
        return None

class WebSocketBinaryEncoder(object):
    def __init__(self, protocols, use_mask = False):
        self.enc = WebSocketEncoder(use_mask)
        self.base64 = "base64" in protocols

    def encode(self, data):
        if self.base64:
            return self.enc.encode_message(1, base64.b64encode(data))
        else:
            return self.enc.encode_message(2, data)


def listen_socket(addr):
    """Return a nonblocking socket listening on the given address."""
    addrinfo = socket.getaddrinfo(addr[0], addr[1], 0, socket.SOCK_STREAM, socket.IPPROTO_TCP)[0]
    s = socket.socket(addrinfo[0], addrinfo[1], addrinfo[2])
    s.setsockopt(socket.SOL_SOCKET, socket.SO_REUSEADDR, 1)
    s.bind(addr)
    s.listen(10)
    s.setblocking(0)
    return s

def format_peername(s):
    try:
        return format_addr(s.getpeername())
    except socket.error, e:
        return "<unconnected>"

# How long to wait for a WebSocket request on the remote socket. It is limited
# to avoid Slowloris-like attacks.
WEBSOCKET_REQUEST_TIMEOUT = 2.0

class WebSocketRequestHandler(BaseHTTPServer.BaseHTTPRequestHandler):
    def __init__(self, request_text, fd):
        self.rfile = cStringIO.StringIO(request_text)
        self.wfile = fd.makefile()
        self.error = False
        self.raw_requestline = self.rfile.readline()
        self.parse_request()

    def log_message(self, *args):
        pass

    def send_error(self, code, message = None):
        BaseHTTPServer.BaseHTTPRequestHandler.send_error(self, code, message)
        self.error = True

MAGIC_GUID = "258EAFA5-E914-47DA-95CA-C5AB0DC85B11"

def handle_websocket_request(fd):
    log(u"handle_websocket_request")
    request_text = fd.recv(10 * 1024)
    handler = WebSocketRequestHandler(request_text, fd)
    if handler.error or not hasattr(handler, "path"):
        return None
    method = handler.command
    path = handler.path
    headers = handler.headers

    # See RFC 6455 section 4.2.1 for this sequence of checks.
    #
    # 1. An HTTP/1.1 or higher GET request, including a "Request-URI"...
    if method != "GET":
        handler.send_error(405)
        return None
    if path != "/":
        handler.send_error(404)
        return None

    # 2. A |Host| header field containing the server's authority.
    # We deliberately skip this test.

    # 3. An |Upgrade| header field containing the value "websocket", treated as
    # an ASCII case-insensitive value.
    if "websocket" not in [x.strip().lower() for x in headers.get("upgrade").split(",")]:
        handler.send_error(400)
        return None

    # 4. A |Connection| header field that includes the token "Upgrade", treated
    # as an ASCII case-insensitive value.
    if "upgrade" not in [x.strip().lower() for x in headers.get("connection").split(",")]:
        handler.send_error(400)
        return None

    # 5. A |Sec-WebSocket-Key| header field with a base64-encoded value that,
    # when decoded, is 16 bytes in length.
    try:
        key = headers.get("sec-websocket-key")
        if len(base64.b64decode(key)) != 16:
            raise TypeError("Sec-WebSocket-Key must be 16 bytes")
    except TypeError:
        handler.send_error(400)
        return None

    # 6. A |Sec-WebSocket-Version| header field, with a value of 13. We also
    # allow 8 from draft-ietf-hybi-thewebsocketprotocol-10.
    version = headers.get("sec-websocket-version")
    KNOWN_VERSIONS = ["8", "13"]
    if version not in KNOWN_VERSIONS:
        # "If this version does not match a version understood by the server,
        # the server MUST abort the WebSocket handshake described in this
        # section and instead send an appropriate HTTP error code (such as 426
        # Upgrade Required) and a |Sec-WebSocket-Version| header field
        # indicating the version(s) the server is capable of understanding."
        handler.send_response(426)
        handler.send_header("Sec-WebSocket-Version", ", ".join(KNOWN_VERSIONS))
        handler.end_headers()
        return None

    # 7. Optionally, an |Origin| header field.

    # 8. Optionally, a |Sec-WebSocket-Protocol| header field, with a list of
    # values indicating which protocols the client would like to speak, ordered
    # by preference.
    protocols_str = headers.get("sec-websocket-protocol")
    if protocols_str is None:
        protocols = []
    else:
        protocols = [x.strip().lower() for x in protocols_str.split(",")]

    # 9. Optionally, a |Sec-WebSocket-Extensions| header field...

    # 10. Optionally, other header fields...

    # See RFC 6455 section 4.2.2, item 5 for these steps.

    # 1. A Status-Line with a 101 response code as per RFC 2616.
    handler.send_response(101)
    # 2. An |Upgrade| header field with value "websocket" as per RFC 2616.
    handler.send_header("Upgrade", "websocket")
    # 3. A |Connection| header field with value "Upgrade".
    handler.send_header("Connection", "Upgrade")
    # 4. A |Sec-WebSocket-Accept| header field.  The value of this header field
    # is constructed by concatenating /key/, defined above in step 4 in Section
    # 4.2.2, with the string "258EAFA5-E914-47DA-95CA-C5AB0DC85B11", taking the
    # SHA-1 hash of this concatenated value to obtain a 20-byte value and
    # base64-encoding (see Section 4 of [RFC4648]) this 20-byte hash.
    accept_key = base64.b64encode(hashlib.sha1(key + MAGIC_GUID).digest())
    handler.send_header("Sec-WebSocket-Accept", accept_key)
    # 5.  Optionally, a |Sec-WebSocket-Protocol| header field, with a value
    # /subprotocol/ as defined in step 4 in Section 4.2.2.
    if "base64" in protocols:
        handler.send_header("Sec-WebSocket-Protocol", "base64")
    # 6.  Optionally, a |Sec-WebSocket-Extensions| header field...

    handler.end_headers()

    return protocols

def grab_string(s, pos):
    """Grab a NUL-terminated string from the given string, starting at the given
    offset. Return (pos, str) tuple, or (pos, None) on error."""
    i = pos
    while i < len(s):
        if s[i] == '\0':
            return (i + 1, s[pos:i])
        i += 1
    return pos, None

def parse_socks_request(data):
    try:
        ver, cmd, dport, o1, o2, o3, o4 = struct.unpack(">BBHBBBB", data[:8])
    except struct.error:
        log(u"Couldn't unpack SOCKS4 header.")
        return None
    if ver != 4:
        log(u"SOCKS header has wrong version (%d)." % ver)
        return None
    if cmd != 1:
        log(u"SOCKS header had wrong command (%d)." % cmd)
        return None
    pos, userid = grab_string(data, 8)
    if userid is None:
        log(u"Couldn't read userid from SOCKS header.")
        return None
    if o1 == 0 and o2 == 0 and o3 == 0 and o4 != 0:
        pos, dest = grab_string(data, pos)
        if dest is None:
            log(u"Couldn't read destination from SOCKS4a header.")
            return None
    else:
        dest = "%d.%d.%d.%d" % (o1, o2, o3, o4)
    return dest, dport

def handle_socks_request(fd):
    log(u"handle_socks_request")
    try:
        addr = fd.getpeername()
        data = fd.recv(100)
    except socket.error, e:
        log(u"Socket error from SOCKS-pending: %s" % repr(str(e)))
        return False
    dest_addr = parse_socks_request(data)
    if dest_addr is None:
        # Error reply.
        fd.sendall(struct.pack(">BBHBBBB", 0, 91, 0, 0, 0, 0, 0))
        return False
    log(u"Got SOCKS request for %s." % format_addr(dest_addr))
    fd.sendall(struct.pack(">BBHBBBB", 0, 90, dest_addr[1], 127, 0, 0, 1))
    # Note we throw away the requested address and port.
    return True

def report_pending():
    log(u"locals  (%d): %s" % (len(locals), [format_peername(x) for x in locals]))
    log(u"remotes (%d): %s" % (len(remotes), [format_peername(x) for x in remotes]))
 
def register():
    if not options.register:
        return

    spec = format_addr((None, options.remote_addr[1]))
    command = ["./flashproxy-reg-http.py"]
    if options.facilitator_addr is None:
        log(u"Registering \"%s\"." % spec)
    else:
        command += [format_addr(options.facilitator_addr)]
    command += ["-a", spec]
    try:
        p = subprocess.Popen(command)
    except OSError, e:
        log(u"Failed to register: %s" % str(e))

def proxy_chunk_local_to_remote(local, remote, data = None):
    if data is None:
        try:
            data = local.recv(65536)
        except socket.error, e: # Can be "Connection reset by peer".
            log(u"Socket error from local: %s" % repr(str(e)))
            remote.close()
            return False
    if not data:
        log(u"EOF from local %s." % format_peername(local))
        local.close()
        remote.close()
        return False
    else:
        try:
            remote.send_chunk(data)
        except socket.error, e:
            log(u"Socket error writing to remote: %s" % repr(str(e)))
            local.close()
            return False
        return True

def proxy_chunk_remote_to_local(remote, local, data = None):
    if data is None:
        try:
            data = remote.recv(65536)
        except socket.error, e: # Can be "Connection reset by peer".
            log(u"Socket error from remote: %s" % repr(str(e)))
            local.close()
            return False
    if not data:
        log(u"EOF from remote %s." % format_peername(remote))
        remote.close()
        local.close()
        return False
    else:
        remote.dec.feed(data)
        while True:
            try:
                data = remote.dec.read()
            except (WebSocketDecoder.MaskingError, ValueError), e:
                log(u"WebSocket decode error from remote: %s" % repr(str(e)))
                remote.close()
                local.close()
                return False
            if data is None:
                break
            elif not data:
                log(u"WebSocket close from remote %s." % format_peername(remote))
                remote.close()
                local.close()
                return False
            try:
                local.send_chunk(data)
            except socket.error, e:
                log(u"Socket error writing to local: %s" % repr(str(e)))
                remote.close()
                return False
        return True

def receive_unlinked(fd, label):
    """Receive and buffer data on a socket that has not been linked yet. Returns
    True iff there was no error and the socket may still be used; otherwise, the
    socket will be closed before returning."""

    try:
        data = fd.recv(1024)
    except socket.error, e:
        log(u"Socket error from %s: %s" % (label, repr(str(e))))
        fd.close()
        return False
    if not data:
        log(u"EOF from unlinked %s %s with %d bytes buffered." % (label, format_peername(fd), len(fd.buf)))
        fd.close()
        return False
    else:
        log(u"Data from unlinked %s %s (%d bytes)." % (label, format_peername(fd), len(data)))
        fd.buf += data
        if len(fd.buf) >= UNCONNECTED_BUFFER_LIMIT:
            log(u"Refusing to buffer more than %d bytes from %s %s." % (UNCONNECTED_BUFFER_LIMIT, label, format_peername(fd)))
            fd.close()
            return False
        return True

def match_proxies():
    while unlinked_remotes and unlinked_locals:
        remote = unlinked_remotes.pop(0)
        local = unlinked_locals.pop(0)
        remote_addr, remote_port = remote.getpeername()
        local_addr, local_port = local.getpeername()
        log(u"Linking %s and %s." % (format_peername(local), format_peername(remote)))
        remote.partner = local
        local.partner = remote
        if remote.buf:
            proxy_chunk_remote_to_local(remote, local, remote.buf)
        if local.buf:
            proxy_chunk_local_to_remote(local, remote, local.buf)

class TimeoutSocket(object):
    def __init__(self, fd):
        self.fd = fd
        self.birthday = time.time()

    def age(self):
        return time.time() - self.birthday

    def __getattr__(self, name):
        return getattr(self.fd, name)

class RemoteSocket(object):
    def __init__(self, fd, protocols):
        self.fd = fd
        self.buf = ""
        self.partner = None
        self.dec = WebSocketBinaryDecoder(protocols, use_mask = True)
        self.enc = WebSocketBinaryEncoder(protocols, use_mask = False)

    def send_chunk(self, data):
        self.sendall(self.enc.encode(data))

    def __getattr__(self, name):
        return getattr(self.fd, name)

class LocalSocket(object):
    def __init__(self, fd):
        self.fd = fd
        self.buf = ""
        self.partner = None

    def send_chunk(self, data):
        self.sendall(data)

    def __getattr__(self, name):
        return getattr(self.fd, name)

def main():
    while True:
        rset = [remote_s, local_s] + websocket_pending + socks_pending + locals + remotes
        rset, _, _ = select.select(rset, [], [], WEBSOCKET_REQUEST_TIMEOUT)
        for fd in rset:
            if fd == remote_s:
                remote_c, addr = fd.accept()
                log(u"Remote connection from %s." % format_addr(addr))
                websocket_pending.append(TimeoutSocket(remote_c))
            elif fd == local_s:
                local_c, addr = fd.accept()
                log(u"Local connection from %s." % format_addr(addr))
                socks_pending.append(local_c)
                register()
            elif fd in websocket_pending:
                log(u"Data from WebSocket-pending %s." % format_addr(addr))
                protocols = handle_websocket_request(fd)
                if protocols is not None:
                    wrapped = RemoteSocket(fd, protocols)
                    remotes.append(wrapped)
                    unlinked_remotes.append(wrapped)
                else:
                    fd.close()
                websocket_pending.remove(fd)
                report_pending()
            elif fd in socks_pending:
                log(u"SOCKS request from %s." % format_addr(addr))
                if handle_socks_request(fd):
                    wrapped = LocalSocket(fd)
                    locals.append(wrapped)
                    unlinked_locals.append(wrapped)
                else:
                    fd.close()
                socks_pending.remove(fd)
                report_pending()
            elif fd in remotes:
                local = fd.partner
                if local:
                    if not proxy_chunk_remote_to_local(fd, local):
                        remotes.remove(fd)
                        locals.remove(local)
                        register()
                else:
                    if not receive_unlinked(fd, "remote"):
                        remotes.remove(fd)
                        unlinked_remotes.remove(fd)
                        register()
                    report_pending()
            elif fd in locals:
                remote = fd.partner
                if remote:
                    if not proxy_chunk_local_to_remote(fd, remote):
                        remotes.remove(remote)
                        locals.remove(fd)
                else:
                    if not receive_unlinked(fd, "local"):
                        locals.remove(fd)
                        unlinked_locals.remove(fd)
                    report_pending()
            match_proxies()
        while websocket_pending:
            pending = websocket_pending[0]
            if pending.age() < WEBSOCKET_REQUEST_TIMEOUT:
                break
            log(u"Expired remote connection from %s." % format_peername(pending))
            pending.close()
            websocket_pending.pop(0)
            report_pending()

if __name__ == "__main__":
    opts, args = getopt.gnu_getopt(sys.argv[1:], "f:hl:r", ["daemon", "facilitator=", "help", "log=", "pidfile=", "register"])
    for o, a in opts:
        if o == "--daemon":
            options.daemonize = True
        elif o == "-f" or o == "--facilitator":
            options.facilitator_addr = parse_addr_spec(a)
        elif o == "-h" or o == "--help":
            usage()
            sys.exit()
        elif o == "-l" or o == "--log":
            options.log_filename = a
        elif o == "--pidfile":
            options.pid_filename = a
        elif o == "-r" or o == "--register":
            options.register = True

    if len(args) == 0:
        options.local_addr = (DEFAULT_LOCAL_ADDRESS, DEFAULT_LOCAL_PORT)
        options.remote_addr = (DEFAULT_REMOTE_ADDRESS, DEFAULT_REMOTE_PORT)
    elif len(args) == 1:
        options.local_addr = parse_addr_spec(args[0], DEFAULT_LOCAL_ADDRESS, DEFAULT_LOCAL_PORT)
        options.remote_addr = (DEFAULT_REMOTE_ADDRESS, DEFAULT_REMOTE_PORT)
    elif len(args) == 2:
        options.local_addr = parse_addr_spec(args[0], DEFAULT_LOCAL_ADDRESS, DEFAULT_LOCAL_PORT)
        options.remote_addr = parse_addr_spec(args[1], DEFAULT_REMOTE_ADDRESS, DEFAULT_REMOTE_PORT)
    else:
        usage(sys.stderr)
        sys.exit(1)

    if options.log_filename:
        options.log_file = open(options.log_filename, "a")
        # Send error tracebacks to the log.
        sys.stderr = options.log_file
    else:
        options.log_file = sys.stdout

    # Local socket, accepting SOCKS requests from localhost
    local_s = listen_socket(options.local_addr)
    # Remote socket, accepting remote WebSocket connections from proxies.
    remote_s = listen_socket(options.remote_addr)

    # New remote sockets waiting to finish their WebSocket negotiation.
    websocket_pending = []
    # Remote connection sockets.
    remotes = []
    # Remotes not yet linked with a local. This is a subset of remotes.
    unlinked_remotes = []
    # New local sockets waiting to finish their SOCKS negotiation.
    socks_pending = []
    # Local Tor sockets, after SOCKS negotiation.
    locals = []
    # Locals not yet linked with a remote. This is a subset of remotes.
    unlinked_locals = []

    register()

    if options.daemonize:
        log(u"Daemonizing.")
        pid = os.fork()
        if pid != 0:
            if options.pid_filename:
                f = open(options.pid_filename, "w")
                print >> f, pid
                f.close()
            sys.exit(0)
    try:
        main()
    except Exception:
        exc = traceback.format_exc()
        log("".join(exc))
