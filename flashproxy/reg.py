import urllib
from collections import namedtuple

from flashproxy.keys import get_pubkey, pubkey_b64enc
from flashproxy.util import parse_addr_spec, format_addr

DEFAULT_REMOTE = ("", 9000)
DEFAULT_FACILITATOR_URL = "https://fp-facilitator.org/"
DEFAULT_TRANSPORT = "websocket"
# Default facilitator pubkey owned by the operator of DEFAULT_FACILITATOR_URL
DEFAULT_FACILITATOR_PUBKEY_PEM = """\
-----BEGIN PUBLIC KEY-----
MIIBIjANBgkqhkiG9w0BAQEFAAOCAQ8AMIIBCgKCAQEA44Mt8c599/4N2fgu6ppN
oatPW1GOgZxxObljFtEy0OWM1eHB35OOn+Kn9MxNHTRxVWwCEi0HYxWNVs2qrXxV
84LmWBz6A65d2qBlgltgLXusiXLrpwxVmJeO+GfmbF8ur0U9JSYxA20cGW/kujNg
XYDGQxO1Gvxq2lHK2LQmBpkfKEE1DMFASmIvlHDQgDj3XBb5lYeOsHZmg16UrGAq
1UH238hgJITPGLXBtwLtJkYbrATJvrEcmvI7QSm57SgYGpaB5ZdCbJL5bag5Pgt6
M5SDDYYY4xxEPzokjFJfCQv+kcyAnzERNMQ9kR41ePTXG62bpngK5iWGeJ5XdkxG
gwIDAQAB
-----END PUBLIC KEY-----
"""

class options(object):
    transport = DEFAULT_TRANSPORT
    facilitator_pubkey = None

def add_module_opts(parser):
    parser.add_argument("--transport", metavar="TRANSPORT",
        help="register using the given transport, default %(default)s.",
        default=DEFAULT_TRANSPORT)
    parser.add_argument("--facilitator-pubkey", metavar="FILENAME",
        help=("encrypt registrations to the given PEM-formatted public "
        "key file (default built-in)."))

    old_parse = parser.parse_args
    def parse_args(namespace):
        options.transport = namespace.transport
        options.facilitator_pubkey = namespace.facilitator_pubkey
        return namespace
    parser.parse_args = lambda *a, **kw: parse_args(old_parse(*a, **kw))

def add_registration_args(parser):
    add_module_opts(parser)
    parser.add_argument("remote_addr", metavar="ADDR:PORT",
        help="external addr+port to register, default %s" %
        format_addr(DEFAULT_REMOTE), default="", nargs="?",
        type=lambda x: parse_addr_spec(x, *DEFAULT_REMOTE))


def build_reg(addr, transport):
    return urllib.urlencode((
        ("client", format_addr(addr)),
        ("client-transport", transport),
    ))

def build_reg_b64enc(addr, transport, urlsafe=False):
    pubkey = get_pubkey(DEFAULT_FACILITATOR_PUBKEY_PEM, options.facilitator_pubkey)
    return pubkey_b64enc(build_reg(addr, transport), pubkey, urlsafe=urlsafe)


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
