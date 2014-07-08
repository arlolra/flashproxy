import re
import socket

_old_socket_getaddrinfo = socket.getaddrinfo

class options(object):
    safe_logging = True
    address_family = socket.AF_UNSPEC

def add_module_opts(parser):
    parser.add_argument("-4",
        help="name lookups use only IPv4.",
        action="store_const", const=socket.AF_INET, dest="address_family")
    parser.add_argument("-6",
        help="name lookups use only IPv6.",
        action="store_const", const=socket.AF_INET6, dest="address_family")
    parser.add_argument("--unsafe-logging",
        help="don't scrub IP addresses and other sensitive information from "
        "logs.", action="store_true")

    old_parse = parser.parse_args
    def parse_args(namespace):
        options.safe_logging = not namespace.unsafe_logging
        options.address_family = namespace.address_family or socket.AF_UNSPEC
        return namespace
    parser.parse_args = lambda *a, **kw: parse_args(old_parse(*a, **kw))

def enforce_address_family(address_family):
    """Force all future name lookups to use the given address family."""
    if address_family != socket.AF_UNSPEC:
        def getaddrinfo_replacement(host, port, family, *args, **kwargs):
            return _old_socket_getaddrinfo(host, port, options.address_family, *args, **kwargs)
        socket.getaddrinfo = getaddrinfo_replacement

def safe_str(s):
    """Return "[scrubbed]" if options.safe_logging is true, and s otherwise."""
    if options.safe_logging:
        return "[scrubbed]"
    else:
        return s

def safe_format_addr(addr):
    return safe_str(format_addr(addr))

def parse_addr_spec(spec, defhost = None, defport = None):
    """Parse a host:port specification and return a 2-tuple ("host", port) as
    understood by the Python socket functions.

    >>> parse_addr_spec("192.168.0.1:9999")
    ('192.168.0.1', 9999)

    If defhost or defport are given and not None, the respective parts of the
    specification may be omitted, and will be filled in with the defaults.
    If defhost or defport are omitted or None, the respective parts of the
    specification must be given, or else a ValueError will be raised.

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
    >>> parse_addr_spec(":")
    Traceback (most recent call last):
    [..]
    ValueError: Bad address specification ":"
    >>> parse_addr_spec(":", "", 0)
    ('', 0)

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
    return host, int(port)

def resolve_to_ip(host, port, af=0, gai_flags=0):
    """Resolves a host string to an IP address in canonical format.

    Note: in many cases this is not necessary since the consumer of the address
    can probably accept host names directly.

    :param: host string to resolve; may be a DNS name or an IP address.
    :param: port of the host
    :param: af address family, default unspecified. set to socket.AF_INET or
        socket.AF_INET6 to force IPv4 or IPv6 name resolution.
    :returns: (IP address in canonical format, port)
    """
    # Forward-resolve the name into an addrinfo struct. Real DNS resolution is
    # done only if resolve is true; otherwise the address must be numeric.
    try:
        addrs = socket.getaddrinfo(host, port, af, 0, 0, gai_flags)
    except socket.gaierror, e:
        raise ValueError("Bad host or port: \"%s\" \"%s\": %s" % (host, port, str(e)))
    if not addrs:
        raise ValueError("Bad host or port: \"%s\" \"%s\"" % (host, port))

    # Convert the result of socket.getaddrinfo (which is a 2-tuple for IPv4 and
    # a 4-tuple for IPv6) into a (host, port) 2-tuple.
    host, port = socket.getnameinfo(addrs[0][4], socket.NI_NUMERICHOST | socket.NI_NUMERICSERV)
    return host, int(port)

def canonical_ip(host, port, af=0):
    """Convert an IP address to a canonical format. Identical to resolve_to_ip,
    except that the host param must already be an IP address."""
    return resolve_to_ip(host, port, af, gai_flags=socket.AI_NUMERICHOST)

def addr_family(ip):
    """Return the address family of an IP address. Raises socket.gaierror if ip
    is not a numeric IP."""
    addrs = socket.getaddrinfo(ip, 0, 0, socket.SOCK_STREAM, socket.IPPROTO_TCP, socket.AI_NUMERICHOST)
    return addrs[0][0]

def format_addr(addr):
    host, port = addr
    host_str = u""
    port_str = u""
    if not (host is None or host == ""):
        # Numeric IPv6 address?
        try:
            af = addr_family(host)
        except socket.gaierror, e:
            af = 0
        if af == socket.AF_INET6:
            host_str = u"[%s]" % host
        else:
            host_str = u"%s" % host
    if port is not None:
        port = int(port)
        if not (0 < port <= 65535):
            raise ValueError("port must be between 1 and 65535 (is %d)" % port)
        port_str = u":%d" % port

    if not host_str and not port_str:
        raise ValueError("host and port may not both be None")
    return u"%s%s" % (host_str, port_str)
