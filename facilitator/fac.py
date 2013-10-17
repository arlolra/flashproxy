import errno
import os
import re
import socket
import stat
import subprocess
import pwd
import urlparse
from collections import namedtuple

DEFAULT_CLIENT_TRANSPORT = "websocket"

# Return true iff the given fd is readable, writable, and executable only by its
# owner.
def check_perms(fd):
    mode = os.fstat(fd)[0]
    return (mode & (stat.S_IRWXG | stat.S_IRWXO)) == 0

# Drop privileges by switching ID to that of the given user.
# http://stackoverflow.com/questions/2699907/dropping-root-permissions-in-python/2699996#2699996
# https://www.securecoding.cert.org/confluence/display/seccode/POS36-C.+Observe+correct+revocation+order+while+relinquishing+privileges
# https://www.securecoding.cert.org/confluence/display/seccode/POS37-C.+Ensure+that+privilege+relinquishment+is+successful
def drop_privs(username):
    uid = pwd.getpwnam(username).pw_uid
    gid = pwd.getpwnam(username).pw_gid
    os.setgroups([])
    os.setgid(gid)
    os.setuid(uid)
    try:
        os.setuid(0)
    except OSError:
        pass
    else:
        raise AssertionError("setuid(0) succeeded after attempting to drop privileges")

# A decorator to ignore "broken pipe" errors.
def catch_epipe(fn):
    def ret(self, *args):
        try:
            return fn(self, *args)
        except socket.error, e:
            try:
                err_num = e.errno
            except AttributeError:
                # Before Python 2.6, exception can be a pair.
                err_num, errstr = e
            except:
                raise
            if err_num != errno.EPIPE:
                raise
    return ret

def parse_addr_spec(spec, defhost = None, defport = None, resolve = False):
    """Parse a host:port specification and return a 2-tuple ("host", port) as
    understood by the Python socket functions.
    >>> parse_addr_spec("192.168.0.1:9999")
    ('192.168.0.1', 9999)

    If defhost or defport are given, those parts of the specification may be
    omitted; if so, they will be filled in with defaults.
    >>> parse_addr_spec("192.168.0.2:8888", defhost="192.168.0.1", defport=9999)
    ('192.168.0.2', 8888)
    >>> parse_addr_spec(":8888", defhost="192.168.0.1", defport=9999)
    ('192.168.0.1', 8888)
    >>> parse_addr_spec("192.168.0.2", defhost="192.168.0.1", defport=9999)
    ('192.168.0.2', 9999)
    >>> parse_addr_spec("192.168.0.2:", defhost="192.168.0.1", defport=9999)
    ('192.168.0.2', 9999)
    >>> parse_addr_spec(":", defhost="192.168.0.1", defport=9999)
    ('192.168.0.1', 9999)
    >>> parse_addr_spec("", defhost="192.168.0.1", defport=9999)
    ('192.168.0.1', 9999)

    If resolve is true, then the host in the specification or the defhost may be
    a domain name, which will be resolved. If resolve is false, then the host
    must be a numeric IPv4 or IPv6 address.

    IPv6 addresses must be enclosed in square brackets."""
    host = None
    port = None
    af = 0
    m = None
    # IPv6 syntax.
    if not m:
        m = re.match(ur'^\[(.+)\]:(\d*)$', spec)
        if m:
            host, port = m.groups()
            af = socket.AF_INET6
    if not m:
        m = re.match(ur'^\[(.+)\]$', spec)
        if m:
            host, = m.groups()
            af = socket.AF_INET6
    # IPv4/hostname/port-only syntax.
    if not m:
        try:
            host, port = spec.split(":", 1)
        except ValueError:
            host = spec
        if re.match(ur'^[\d.]+$', host):
            af = socket.AF_INET
        else:
            af = 0
    host = host or defhost
    port = port or defport
    if host is None or port is None:
        raise ValueError("Bad address specification \"%s\"" % spec)

    # Now we have split around the colon and have a guess at the address family.
    # Forward-resolve the name into an addrinfo struct. Real DNS resolution is
    # done only if resolve is true; otherwise the address must be numeric.
    if resolve:
        flags = 0
    else:
        flags = socket.AI_NUMERICHOST
    try:
        addrs = socket.getaddrinfo(host, port, af, socket.SOCK_STREAM, socket.IPPROTO_TCP, flags)
    except socket.gaierror, e:
        raise ValueError("Bad host or port: \"%s\" \"%s\": %s" % (host, port, str(e)))
    if not addrs:
        raise ValueError("Bad host or port: \"%s\" \"%s\"" % (host, port))

    # Convert the result of socket.getaddrinfo (which is a 2-tuple for IPv4 and
    # a 4-tuple for IPv6) into a (host, port) 2-tuple.
    host, port = socket.getnameinfo(addrs[0][4], socket.NI_NUMERICHOST | socket.NI_NUMERICSERV)
    port = int(port)
    return host, port

def format_addr(addr):
    host, port = addr
    host_str = u""
    port_str = u""
    if host is not None:
        # Numeric IPv6 address?
        try:
            addrs = socket.getaddrinfo(host, port, 0, socket.SOCK_STREAM, socket.IPPROTO_TCP, socket.AI_NUMERICHOST)
            af = addrs[0][0]
        except socket.gaierror, e:
            af = 0
        if af == socket.AF_INET6:
            host_str = u"[%s]" % host
        else:
            host_str = u"%s" % host
    if port is not None:
        if not (0 < port <= 65535):
            raise ValueError("port must be between 1 and 65535 (is %d)" % port)
        port_str = u":%d" % port

    if not host_str and not port_str:
        raise ValueError("host and port may not both be None")
    return u"%s%s" % (host_str, port_str)

def get_single(qs, key, default=None):
    try:
        vals = qs[key]
    except KeyError:
        if default is None:
            raise ValueError("missing %r key" % key)
        vals = (default,)
    if len(vals) != 1:
        raise ValueError("more than one %r key" % key)
    return vals[0]

def read_client_registrations(body, defhost=None, defport=None):
    """Parse the lines of body and yield an Endpoint for each."""
    for line in body.splitlines():
        qs = urlparse.parse_qs(line, keep_blank_values=True, strict_parsing=True)
        addr = parse_addr_spec(get_single(qs, "client"), defhost, defport)
        transport = get_single(qs, "client-transport", DEFAULT_CLIENT_TRANSPORT)
        yield Endpoint(addr, transport)


class Transport(namedtuple("Transport", "inner outer")):
    @classmethod
    def parse(cls, transport):
        if isinstance(transport, cls):
            return transport
        elif type(transport) == str:
            if "|" in transport:
                inner, outer = transport.rsplit("|", 1)
            else:
                inner, outer = "", transport
            return cls(inner, outer)
        else:
            raise ValueError("could not parse transport: %s" % transport)

    def __init__(self, inner, outer):
        if not outer:
            raise ValueError("outer (proxy) part of transport must be non-empty: %s" % str(self))

    def __str__(self):
        return "%s|%s" % (self.inner, self.outer) if self.inner else self.outer


class Endpoint(namedtuple("Endpoint", "addr transport")):
    @classmethod
    def parse(cls, spec, transport, defhost = None, defport = None):
        host, port = parse_addr_spec(spec, defhost, defport)
        return cls((host, port), Transport.parse(transport))


def skip_space(pos, line):
    """Skip a (possibly empty) sequence of space characters (the ASCII character
    '\x20' exactly). Returns a pair (pos, num_skipped)."""
    begin = pos
    while pos < len(line) and line[pos] == "\x20":
        pos += 1
    return pos, pos - begin

TOKEN_CHARS = set("abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789_-")
def get_token(pos, line):
    begin = pos
    while pos < len(line) and line[pos] in TOKEN_CHARS:
        pos += 1
    if begin == pos:
        raise ValueError("No token found at position %d" % pos)
    return pos, line[begin:pos]

def get_quoted_string(pos, line):
    chars = []
    if not (pos < len(line) and line[pos] == '"'):
        raise ValueError("Expected '\"' at beginning of quoted string.")
    pos += 1
    while pos < len(line) and line[pos] != '"':
        if line[pos] == '\\':
            pos += 1
            if not (pos < len(line)):
                raise ValueError("End of line after backslash in quoted string")
        chars.append(line[pos])
        pos += 1
    if not (pos < len(line) and line[pos] == '"'):
        raise ValueError("Expected '\"' at end of quoted string.")
    pos += 1
    return pos, "".join(chars)

def parse_transaction(line):
    """A transaction is a command followed by zero or more key-value pairs. Like so:
      COMMAND KEY="VALUE" KEY="\"ESCAPED\" VALUE"
    Values must be quoted. Any byte value may be escaped with a backslash.
    Returns a pair: (COMMAND, ((KEY1, VALUE1), (KEY2, VALUE2), ...)).
    """
    pos = 0
    pos, skipped = skip_space(pos, line)
    pos, command = get_token(pos, line)

    pairs = []
    while True:
        pos, skipped = skip_space(pos, line)
        if not (pos < len(line)):
            break
        if skipped == 0:
            raise ValueError("Expected space before key-value pair")
        pos, key = get_token(pos, line)
        if not (pos < len(line) and line[pos] == '='):
            raise ValueError("No '=' found after key")
        pos += 1
        pos, value = get_quoted_string(pos, line)
        pairs.append((key, value))
    return command, tuple(pairs)

def param_first(key, params):
    """Search 'params' for 'key' and return the first value that
    occurs. If 'key' was not found, return None."""
    for k, v in params:
        if key == k:
            return v
    return None

def param_getlist(key, params):
    """Search 'params' for 'key' and return a list with its values. If
    'key' did not appear in 'params', return the empty list."""
    result = []
    for k, v in params:
        if key == k:
            result.append(v)
    return result

def quote_string(s):
    chars = []
    for c in s:
        if c == "\\":
            c = "\\\\"
        elif c == "\"":
            c = "\\\""
        chars.append(c)
    return "\"" + "".join(chars) + "\""

def render_transaction(command, *params):
    parts = [command]
    for key, value in params:
        parts.append("%s=%s" % (key, quote_string(value)))
    return " ".join(parts)

def fac_socket(facilitator_addr):
    return socket.create_connection(facilitator_addr, 1.0).makefile()

def transact(f, command, *params):
    transaction = render_transaction(command, *params)
    print >> f, transaction
    f.flush()
    line = f.readline()
    if not (len(line) > 0 and line[-1] == '\n'):
        raise ValueError("No newline at end of string returned by facilitator")
    return parse_transaction(line[:-1])

def put_reg(facilitator_addr, client_addr, transport):
    """Send a registration to the facilitator using a one-time socket. Returns
    true iff the command was successful."""
    f = fac_socket(facilitator_addr)
    params = [("CLIENT", format_addr(client_addr))]
    params.append(("TRANSPORT", transport))
    try:
        command, params = transact(f, "PUT", *params)
    finally:
        f.close()
    return command == "OK"

def get_reg(facilitator_addr, proxy_addr, proxy_transport_list):
    """
    Get a client registration for proxy proxy_addr from the
    facilitator at facilitator_addr using a one-time
    socket. proxy_transport_list is a list containing the transport names that
    the flashproxy supports.

    Returns a dict with keys "client", "client-transport", "relay",
    and "relay-transport" if successful, or a dict with the key "client"
    mapped to the value "" if there are no registrations available for
    proxy_addr. Raises an exception otherwise."""
    f = fac_socket(facilitator_addr)

    # Form a list (in transact() format) with the transports that we
    # should send to the facilitator.  Then pass that list to the
    # transact() function.
    # For example, PROXY_TRANSPORT=obfs2 PROXY_TRANSPORT=obfs3.
    transports = [("PROXY_TRANSPORT", tp) for tp in proxy_transport_list]

    try:
        command, params = transact(f, "GET", ("FROM", format_addr(proxy_addr)), *transports)
    finally:
        f.close()
    response = {}
    check_back_in = param_first("CHECK-BACK-IN", params)
    if check_back_in is not None:
        try:
            float(check_back_in)
        except ValueError:
            raise ValueError("Facilitator returned non-numeric polling interval.")
        response["check-back-in"] = check_back_in
    if command == "NONE":
        response["client"] = ""
        return response
    elif command == "OK":
        client_spec = param_first("CLIENT", params)
        client_transport = param_first("CLIENT-TRANSPORT", params)
        relay_spec = param_first("RELAY", params)
        relay_transport = param_first("RELAY-TRANSPORT", params)
        if not client_spec:
            raise ValueError("Facilitator did not return CLIENT")
        if not client_transport:
            raise ValueError("Facilitator did not return CLIENT-TRANSPORT")
        if not relay_spec:
            raise ValueError("Facilitator did not return RELAY")
        if not relay_transport:
            raise ValueError("Facilitator did not return RELAY-TRANSPORT")
        # Check the syntax returned by the facilitator.
        client = parse_addr_spec(client_spec)
        relay = parse_addr_spec(relay_spec)
        response["client"] = format_addr(client)
        response["client-transport"] = client_transport
        response["relay"] = format_addr(relay)
        response["relay-transport"] = relay_transport
        return response
    else:
        raise ValueError("Facilitator response was not \"OK\"")

def put_reg_base64(b64):
    """Attempt to add a registration by running a facilitator-reg program
    locally."""
    # Padding is optional, but the python base64 functions can't
    # handle lack of padding. Add it here. Assumes correct encoding.
    mod = len(b64) % 4
    if mod != 0:
        b64 += (4 - mod) * "="
    p = subprocess.Popen(["facilitator-reg"], stdin=subprocess.PIPE)
    stdout, stderr = p.communicate(b64)
    return p.returncode == 0
