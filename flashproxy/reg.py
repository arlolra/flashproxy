from collections import namedtuple

from flashproxy.util import parse_addr_spec

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
