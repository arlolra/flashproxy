import re
import socket

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
    return af, host, int(port)

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
        port_str = u":%d" % port

    if not host_str and not port_str:
        raise ValueError("host and port may not both be None")
    return u"%s%s" % (host_str, port_str)

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
    for k, v in params:
        if key == k:
            return v
    return None

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
