#!/usr/bin/env python

import unittest

from flashproxy.util import parse_addr_spec, canonical_ip

class ParseAddrSpecTest(unittest.TestCase):
    def test_ipv4(self):
        self.assertEqual(parse_addr_spec("192.168.0.1:9999"), ("192.168.0.1", 9999))

    def test_ipv6(self):
        self.assertEqual(parse_addr_spec("[12::34]:9999"), ("12::34", 9999))

    def test_defhost_defport_ipv4(self):
        self.assertEqual(parse_addr_spec("192.168.0.2:8888", defhost="192.168.0.1", defport=9999), ("192.168.0.2", 8888))
        self.assertEqual(parse_addr_spec("192.168.0.2:", defhost="192.168.0.1", defport=9999), ("192.168.0.2", 9999))
        self.assertEqual(parse_addr_spec("192.168.0.2", defhost="192.168.0.1", defport=9999), ("192.168.0.2", 9999))
        self.assertEqual(parse_addr_spec(":8888", defhost="192.168.0.1", defport=9999), ("192.168.0.1", 8888))
        self.assertEqual(parse_addr_spec(":", defhost="192.168.0.1", defport=9999), ("192.168.0.1", 9999))
        self.assertEqual(parse_addr_spec("", defhost="192.168.0.1", defport=9999), ("192.168.0.1", 9999))

    def test_defhost_defport_ipv6(self):
        self.assertEqual(parse_addr_spec("[1234::2]:8888", defhost="1234::1", defport=9999), ("1234::2", 8888))
        self.assertEqual(parse_addr_spec("[1234::2]:", defhost="1234::1", defport=9999), ("1234::2", 9999))
        self.assertEqual(parse_addr_spec("[1234::2]", defhost="1234::1", defport=9999), ("1234::2", 9999))
        self.assertEqual(parse_addr_spec(":8888", defhost="1234::1", defport=9999), ("1234::1", 8888))
        self.assertEqual(parse_addr_spec(":", defhost="1234::1", defport=9999), ("1234::1", 9999))
        self.assertEqual(parse_addr_spec("", defhost="1234::1", defport=9999), ("1234::1", 9999))

    def test_canonical_ip_noresolve(self):
        """Test that canonical_ip does not do DNS resolution by default."""
        self.assertRaises(ValueError, canonical_ip, *parse_addr_spec("example.com:80"))

if __name__ == "__main__":
    unittest.main()
