import os.path
import unittest

from flashproxy.keys import PIN_GOOGLE_CA_CERT, PIN_GOOGLE_PUBKEY_SHA1, check_certificate_pin, temp_cert

class TempCertTest(unittest.TestCase):

    def test_temp_cert_success(self):
        fn = None
        with temp_cert(PIN_GOOGLE_CA_CERT) as ca_filename:
            self.assertTrue(os.path.exists(ca_filename))
            with open(ca_filename) as f:
                lines = f.readlines()
                self.assertIn("-----BEGIN CERTIFICATE-----\n", lines)
        self.assertFalse(os.path.exists(ca_filename))

    def test_temp_cert_raise(self):
        fn = None
        try:
            with temp_cert(PIN_GOOGLE_CA_CERT) as ca_filename:
                raise ValueError()
            self.fail()
        except ValueError:
            self.assertFalse(os.path.exists(ca_filename))
