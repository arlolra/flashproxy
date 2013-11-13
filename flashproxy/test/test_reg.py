#!/usr/bin/env python

import unittest

from flashproxy.reg import Transport

class TransportTest(unittest.TestCase):

    def test_transport_parse(self):
        self.assertEquals(Transport.parse("a"), Transport("", "a"))
        self.assertEquals(Transport.parse("|a"), Transport("", "a"))
        self.assertEquals(Transport.parse("a|b|c"), Transport("a|b","c"))
        self.assertEquals(Transport.parse(Transport("a|b","c")), Transport("a|b","c"))
        self.assertRaises(ValueError, Transport, "", "")
        self.assertRaises(ValueError, Transport, "a", "")
        self.assertRaises(ValueError, Transport.parse, "")
        self.assertRaises(ValueError, Transport.parse, "|")
        self.assertRaises(ValueError, Transport.parse, "a|")
        self.assertRaises(ValueError, Transport.parse, ["a"])
        self.assertRaises(ValueError, Transport.parse, [Transport("a", "b")])

if __name__ == "__main__":
    unittest.main()
