#!/usr/bin/env python

import unittest

from flashproxy.fac import parse_transaction, read_client_registrations

class ParseTransactionTest(unittest.TestCase):
    def test_empty_string(self):
        self.assertRaises(ValueError, parse_transaction, "")

    def test_correct(self):
        self.assertEqual(parse_transaction("COMMAND"), ("COMMAND", ()))
        self.assertEqual(parse_transaction("COMMAND X=\"\""), ("COMMAND", (("X", ""),)))
        self.assertEqual(parse_transaction("COMMAND X=\"ABC\""), ("COMMAND", (("X", "ABC"),)))
        self.assertEqual(parse_transaction("COMMAND X=\"\\A\\B\\C\""), ("COMMAND", (("X", "ABC"),)))
        self.assertEqual(parse_transaction("COMMAND X=\"\\\\\\\"\""), ("COMMAND", (("X", "\\\""),)))
        self.assertEqual(parse_transaction("COMMAND X=\"ABC\" Y=\"DEF\""), ("COMMAND", (("X", "ABC"), ("Y", "DEF"))))
        self.assertEqual(parse_transaction("COMMAND KEY-NAME=\"ABC\""), ("COMMAND", (("KEY-NAME", "ABC"),)))
        self.assertEqual(parse_transaction("COMMAND KEY_NAME=\"ABC\""), ("COMMAND", (("KEY_NAME", "ABC"),)))

    def test_missing_command(self):
        self.assertRaises(ValueError, parse_transaction, "X=\"ABC\"")
        self.assertRaises(ValueError, parse_transaction, " X=\"ABC\"")

    def test_missing_space(self):
        self.assertRaises(ValueError, parse_transaction, "COMMAND/X=\"ABC\"")
        self.assertRaises(ValueError, parse_transaction, "COMMAND X=\"ABC\"Y=\"DEF\"")

    def test_bad_quotes(self):
        self.assertRaises(ValueError, parse_transaction, "COMMAND X=\"")
        self.assertRaises(ValueError, parse_transaction, "COMMAND X=\"ABC")
        self.assertRaises(ValueError, parse_transaction, "COMMAND X=\"ABC\" Y=\"ABC")
        self.assertRaises(ValueError, parse_transaction, "COMMAND X=\"ABC\\")

    def test_truncated(self):
        self.assertRaises(ValueError, parse_transaction, "COMMAND X=")

    def test_newline(self):
        self.assertRaises(ValueError, parse_transaction, "COMMAND X=\"ABC\" \nY=\"DEF\"")

class ReadClientRegistrationsTest(unittest.TestCase):
    def testSingle(self):
        l = list(read_client_registrations(""))
        self.assertEqual(len(l), 0)
        l = list(read_client_registrations("client=1.2.3.4:1111"))
        self.assertEqual(len(l), 1)
        self.assertEqual(l[0].addr, ("1.2.3.4", 1111))
        l = list(read_client_registrations("client=1.2.3.4:1111\n"))
        self.assertEqual(len(l), 1)
        self.assertEqual(l[0].addr, ("1.2.3.4", 1111))
        l = list(read_client_registrations("foo=bar&client=1.2.3.4:1111&baz=quux"))
        self.assertEqual(len(l), 1)
        self.assertEqual(l[0].addr, ("1.2.3.4", 1111))
        l = list(read_client_registrations("foo=b%3dar&client=1.2.3.4%3a1111"))
        self.assertEqual(len(l), 1)
        self.assertEqual(l[0].addr, ("1.2.3.4", 1111))
        l = list(read_client_registrations("client=%5b1::2%5d:3333"))
        self.assertEqual(len(l), 1)
        self.assertEqual(l[0].addr, ("1::2", 3333))

    def testDefaultAddress(self):
        l = list(read_client_registrations("client=:1111&transport=websocket", defhost="1.2.3.4"))
        self.assertEqual(l[0].addr, ("1.2.3.4", 1111))
        l = list(read_client_registrations("client=1.2.3.4:&transport=websocket", defport=1111))
        self.assertEqual(l[0].addr, ("1.2.3.4", 1111))

    def testDefaultTransport(self):
        l = list(read_client_registrations("client=1.2.3.4:1111"))
        self.assertEqual(l[0].transport, "websocket")

    def testMultiple(self):
        l = list(read_client_registrations("client=1.2.3.4:1111&foo=bar\nfoo=bar&client=5.6.7.8:2222"))
        self.assertEqual(len(l), 2)
        self.assertEqual(l[0].addr, ("1.2.3.4", 1111))
        self.assertEqual(l[1].addr, ("5.6.7.8", 2222))
        l = list(read_client_registrations("client=1.2.3.4:1111&foo=bar\nfoo=bar&client=%5b1::2%5d:3333"))
        self.assertEqual(len(l), 2)
        self.assertEqual(l[0].addr, ("1.2.3.4", 1111))
        self.assertEqual(l[1].addr, ("1::2", 3333))

    def testInvalid(self):
        # Missing "client".
        with self.assertRaises(ValueError):
            list(read_client_registrations("foo=bar"))
        # More than one "client".
        with self.assertRaises(ValueError):
            list(read_client_registrations("client=1.2.3.4:1111&foo=bar&client=5.6.7.8:2222"))
        # Single client with bad syntax.
        with self.assertRaises(ValueError):
            list(read_client_registrations("client=1.2.3.4,1111"))

if __name__ == "__main__":
    unittest.main()
