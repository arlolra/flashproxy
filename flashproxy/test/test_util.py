#!/usr/bin/env python

import socket
import unittest

from flashproxy.util import parse_addr_spec, canonical_ip, addr_family, format_addr

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

    def test_empty_defaults(self):
        self.assertEqual(parse_addr_spec("192.168.0.2:8888"), ("192.168.0.2", 8888))
        self.assertEqual(parse_addr_spec("", defhost="", defport=0), ("", 0))
        self.assertEqual(parse_addr_spec(":8888", defhost=""), ("", 8888))
        self.assertRaises(ValueError, parse_addr_spec, ":8888")
        self.assertEqual(parse_addr_spec("192.168.0.2", defport=0), ("192.168.0.2", 0))
        self.assertRaises(ValueError, parse_addr_spec, "192.168.0.2")

    def test_canonical_ip_noresolve(self):
        """Test that canonical_ip does not do DNS resolution by default."""
        self.assertRaises(ValueError, canonical_ip, *parse_addr_spec("example.com:80"))

class AddrFamilyTest(unittest.TestCase):
    def test_ipv4(self):
        self.assertEqual(addr_family("1.2.3.4"), socket.AF_INET)

    def test_ipv6(self):
        self.assertEqual(addr_family("1:2::3:4"), socket.AF_INET6)

    def test_name(self):
        self.assertRaises(socket.gaierror, addr_family, "localhost")

class FormatAddrTest(unittest.TestCase):
    def test_none_none(self):
        self.assertRaises(ValueError, format_addr, (None, None))

    def test_none_port(self):
        self.assertEqual(format_addr((None, 1234)), ":1234")

    def test_none_invalid(self):
        self.assertRaises(ValueError, format_addr, (None, "string"))

    def test_empty_none(self):
        self.assertRaises(ValueError, format_addr, ("", None))

    def test_empty_port(self):
        self.assertEqual(format_addr(("", 1234)), ":1234")

    def test_empty_invalid(self):
        self.assertRaises(ValueError, format_addr, ("", "string"))

    def test_ipv4_none(self):
        self.assertEqual(format_addr(("1.2.3.4", None)), "1.2.3.4")

    def test_ipv4_port(self):
        self.assertEqual(format_addr(("1.2.3.4", 1234)), "1.2.3.4:1234")

    def test_ipv4_invalid(self):
        self.assertRaises(ValueError, format_addr, ("1.2.3.4", "string"))

    def test_ipv6_none(self):
        self.assertEqual(format_addr(("1:2::3:4", None)), "[1:2::3:4]")

    def test_ipv6_port(self):
        self.assertEqual(format_addr(("1:2::3:4", 1234)), "[1:2::3:4]:1234")

    def test_ipv6_invalid(self):
        self.assertRaises(ValueError, format_addr, ("1:2::3:4", "string"))

    def test_name_none(self):
        self.assertEqual(format_addr(("localhost", None)), "localhost")

    def test_name_port(self):
        self.assertEqual(format_addr(("localhost", 1234)), "localhost:1234")

    def test_name_invalid(self):
        self.assertRaises(ValueError, format_addr, ("localhost", "string"))

if __name__ == "__main__":
    unittest.main()
