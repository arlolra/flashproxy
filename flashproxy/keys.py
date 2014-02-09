import errno
import os
import tempfile

from hashlib import sha1

# We trust no other CA certificate than this.
#
# To find the certificate to copy here,
# $ strace openssl s_client -connect FRONT_DOMAIN:443 -verify 10 -CApath /etc/ssl/certs 2>&1 | grep /etc/ssl/certs
# stat("/etc/ssl/certs/XXXXXXXX.0", {st_mode=S_IFREG|0644, st_size=YYYY, ...}) = 0
PIN_GOOGLE_CA_CERT = """\
subject=/C=US/O=Equifax/OU=Equifax Secure Certificate Authority
issuer=/C=US/O=Equifax/OU=Equifax Secure Certificate Authority
-----BEGIN CERTIFICATE-----
MIIDIDCCAomgAwIBAgIENd70zzANBgkqhkiG9w0BAQUFADBOMQswCQYDVQQGEwJV
UzEQMA4GA1UEChMHRXF1aWZheDEtMCsGA1UECxMkRXF1aWZheCBTZWN1cmUgQ2Vy
dGlmaWNhdGUgQXV0aG9yaXR5MB4XDTk4MDgyMjE2NDE1MVoXDTE4MDgyMjE2NDE1
MVowTjELMAkGA1UEBhMCVVMxEDAOBgNVBAoTB0VxdWlmYXgxLTArBgNVBAsTJEVx
dWlmYXggU2VjdXJlIENlcnRpZmljYXRlIEF1dGhvcml0eTCBnzANBgkqhkiG9w0B
AQEFAAOBjQAwgYkCgYEAwV2xWGcIYu6gmi0fCG2RFGiYCh7+2gRvE4RiIcPRfM6f
BeC4AfBONOziipUEZKzxa1NfBbPLZ4C/QgKO/t0BCezhABRP/PvwDN1Dulsr4R+A
cJkVV5MW8Q+XarfCaCMczE1ZMKxRHjuvK9buY0V7xdlfUNLjUA86iOe/FP3gx7kC
AwEAAaOCAQkwggEFMHAGA1UdHwRpMGcwZaBjoGGkXzBdMQswCQYDVQQGEwJVUzEQ
MA4GA1UEChMHRXF1aWZheDEtMCsGA1UECxMkRXF1aWZheCBTZWN1cmUgQ2VydGlm
aWNhdGUgQXV0aG9yaXR5MQ0wCwYDVQQDEwRDUkwxMBoGA1UdEAQTMBGBDzIwMTgw
ODIyMTY0MTUxWjALBgNVHQ8EBAMCAQYwHwYDVR0jBBgwFoAUSOZo+SvSspXXR9gj
IBBPM5iQn9QwHQYDVR0OBBYEFEjmaPkr0rKV10fYIyAQTzOYkJ/UMAwGA1UdEwQF
MAMBAf8wGgYJKoZIhvZ9B0EABA0wCxsFVjMuMGMDAgbAMA0GCSqGSIb3DQEBBQUA
A4GBAFjOKer89961zgK5F7WF0bnj4JXMJTENAKaSbn+2kmOeUJXRmm/kEd5jhW6Y
7qj/WsjTVbJmcVfewCHrPSqnI0kBBIZCe/zuf6IWUrVnZ9NA2zsmWLIodz2uFHdh
1voqZiegDfqnc1zqcPGUIWVEX/r87yloqaKHee9570+sB3c4
-----END CERTIFICATE-----
"""
# SHA-1 digest of expected public keys. Any of these is valid. See
# http://www.imperialviolet.org/2011/05/04/pinning.html for the reason behind
# hashing the public key, not the entire certificate.
PIN_GOOGLE_PUBKEY_SHA1 = (
    # https://src.chromium.org/viewvc/chrome/trunk/src/net/http/transport_security_state_static.h?revision=209003&view=markup
    # kSPKIHash_Google1024
    "\x40\xc5\x40\x1d\x6f\x8c\xba\xf0\x8b\x00\xed\xef\xb1\xee\x87\xd0\x05\xb3\xb9\xcd",
    # kSPKIHash_GoogleG2
    "\x43\xda\xd6\x30\xee\x53\xf8\xa9\x80\xca\x6e\xfd\x85\xf4\x6a\xa3\x79\x90\xe0\xea",
)

# Registrations are encrypted with this public key before being emailed. Only
# the facilitator operators should have the corresponding private key. Given a
# private key in reg-email, get the public key like this:
# openssl rsa -pubout < reg-email > reg-email.pub
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

def check_certificate_pin(sock, cert_pubkey):
    found = []
    for cert in sock.get_peer_cert_chain():
        pubkey_der = cert.get_pubkey().as_der()
        pubkey_digest = sha1(pubkey_der).digest()
        if pubkey_digest in cert_pubkey:
            break
        found.append(pubkey_digest)
    else:
        found = "(" + ", ".join(x.encode("hex") for x in found) + ")"
        expected = "(" + ", ".join(x.encode("hex") for x in cert_pubkey) + ")"
        raise ValueError("Public key does not match pin: got %s but expected any of %s" % (found, expected))

def get_state_dir():
    """Get a directory where we can put temporary files. Returns None if any
    suitable temporary directory will do."""
    pt_dir = os.environ.get("TOR_PT_STATE_LOCATION")
    if pt_dir is None:
        return None
    try:
        os.makedirs(pt_dir)
    except OSError, e:
        if e.errno != errno.EEXIST:
            raise
    return pt_dir

class temp_cert(object):
    """Implements a with-statement over raw certificate data."""

    def __init__(self, certdata):
        fd, self.path = tempfile.mkstemp(prefix="fp-cert-temp-", dir=get_state_dir(), suffix=".crt")
        os.write(fd, certdata)
        os.close(fd)

    def __enter__(self):
        return self.path

    def __exit__(self, type, value, traceback):
        os.unlink(self.path)
