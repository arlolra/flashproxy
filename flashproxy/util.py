import re
import socket

def parse_addr_spec(spec, defhost = None, defport = None):
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
    if port is not None:
        port = int(port)
    return host, port

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
        result = u"[%s]" % host
    else:
        result = "%s" % host
    if port is not None:
        result += u":%d" % port
    return result
