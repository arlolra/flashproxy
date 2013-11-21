import socket
import subprocess
import urlparse

from flashproxy import reg
from flashproxy.util import parse_addr_spec, format_addr

DEFAULT_CLIENT_TRANSPORT = "websocket"

def read_client_registrations(body, defhost=None, defport=None):
    """Yield client registrations (as Endpoints) from an encoded registration
    message body. The message format is one registration per line, with each
    line being encoded as application/x-www-form-urlencoded. The key "client" is
    required and contains the client address and port (perhaps filled in by
    defhost and defport). The key "client-transport" is optional and defaults to
    "websocket".
    Example:
      client=1.2.3.4:9000&client-transport=websocket
      client=1.2.3.4:9090&client-transport=obfs3|websocket
    """
    for line in body.splitlines():
        qs = urlparse.parse_qs(line, keep_blank_values=True, strict_parsing=True)
        # Get the unique value associated with the given key in qs. If the key
        # is absent or appears more than once, raise ValueError.
        def get_unique(key, default=None):
            try:
                vals = qs[key]
            except KeyError:
                if default is None:
                    raise ValueError("missing %r key" % key)
                vals = (default,)
            if len(vals) != 1:
                raise ValueError("more than one %r key" % key)
            return vals[0]
        addr = parse_addr_spec(get_unique("client"), defhost, defport)
        transport = get_unique("client-transport", DEFAULT_CLIENT_TRANSPORT)
        yield reg.Endpoint(addr, transport)

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
    true iff the command was successful. transport is a transport string such as
    "websocket" or "obfs3|websocket"."""
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
    # For example, PROXY-TRANSPORT=obfs2 PROXY-TRANSPORT=obfs3.
    transports = [("PROXY-TRANSPORT", tp) for tp in proxy_transport_list]

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

def put_reg_proc(args, data):
    """Attempt to add a registration by running a program."""
    p = subprocess.Popen(args, stdin=subprocess.PIPE)
    stdout, stderr = p.communicate(data)
    return p.returncode == 0
