#!/usr/bin/env python

from cStringIO import StringIO
import os
import socket
import subprocess
import tempfile
import sys
import time
import unittest

import fac
from fac import Transport, Endpoint

# Import the facilitator program as a module.
import imp
dont_write_bytecode = sys.dont_write_bytecode
sys.dont_write_bytecode = True
facilitator = imp.load_source("facilitator", os.path.join(os.path.dirname(__file__), "facilitator"))
Endpoints = facilitator.Endpoints
parse_relay_file = facilitator.parse_relay_file
sys.dont_write_bytecode = dont_write_bytecode
del dont_write_bytecode
del facilitator

FACILITATOR_HOST = "127.0.0.1"
FACILITATOR_PORT = 39002 # diff port to not conflict with production service
FACILITATOR_ADDR = (FACILITATOR_HOST, FACILITATOR_PORT)
CLIENT_TP = "websocket"
RELAY_TP = "websocket"
PROXY_TPS = ["websocket", "webrtc"]

def gimme_socket(host, port):
    addrinfo = socket.getaddrinfo(host, port, 0, socket.SOCK_STREAM, socket.IPPROTO_TCP)[0]
    s = socket.socket(addrinfo[0], addrinfo[1], addrinfo[2])
    s.settimeout(10.0)
    s.connect(addrinfo[4])
    return s

class EndpointsTest(unittest.TestCase):

    def setUp(self):
        self.pts = Endpoints(af=socket.AF_INET)

    def test_addEndpoints_twice(self):
        self.pts.addEndpoint("A", "a|b|p")
        self.assertFalse(self.pts.addEndpoint("A", "zzz"))
        self.assertEquals(self.pts._endpoints["A"], Transport("a|b", "p"))

    def test_delEndpoints_twice(self):
        self.pts.addEndpoint("A", "a|b|p")
        self.assertTrue(self.pts.delEndpoint("A"))
        self.assertFalse(self.pts.delEndpoint("A"))
        self.assertEquals(self.pts._endpoints.get("A"), None)

    def test_Endpoints_indexing(self):
        self.assertEquals(self.pts._indexes.get("p"), None)
        # test defaultdict works as expected
        self.assertEquals(self.pts._indexes["p"]["a|b"], set(""))
        self.pts.addEndpoint("A", "a|b|p")
        self.assertEquals(self.pts._indexes["p"]["a|b"], set("A"))
        self.pts.addEndpoint("B", "a|b|p")
        self.assertEquals(self.pts._indexes["p"]["a|b"], set("AB"))
        self.pts.delEndpoint("A")
        self.assertEquals(self.pts._indexes["p"]["a|b"], set("B"))
        self.pts.delEndpoint("B")
        self.assertEquals(self.pts._indexes["p"]["a|b"], set(""))

    def test_serveReg_maxserve_infinite_roundrobin(self):
        # case for servers, they never exhaust
        self.pts.addEndpoint("A", "a|p")
        self.pts.addEndpoint("B", "a|p")
        self.pts.addEndpoint("C", "a|p")
        for i in xrange(64): # 64 is infinite ;)
            served = set()
            served.add(self.pts._serveReg("ABC").addr)
            served.add(self.pts._serveReg("ABC").addr)
            served.add(self.pts._serveReg("ABC").addr)
            self.assertEquals(served, set("ABC"))

    def test_serveReg_maxserve_finite_exhaustion(self):
        # case for clients, we don't want to keep serving them
        self.pts = Endpoints(af=socket.AF_INET, maxserve=5)
        self.pts.addEndpoint("A", "a|p")
        self.pts.addEndpoint("B", "a|p")
        self.pts.addEndpoint("C", "a|p")
        # test getNumUnservedEndpoints whilst we're at it
        self.assertEquals(self.pts.getNumUnservedEndpoints(), 3)
        served = set()
        served.add(self.pts._serveReg("ABC").addr)
        self.assertEquals(self.pts.getNumUnservedEndpoints(), 2)
        served.add(self.pts._serveReg("ABC").addr)
        self.assertEquals(self.pts.getNumUnservedEndpoints(), 1)
        served.add(self.pts._serveReg("ABC").addr)
        self.assertEquals(self.pts.getNumUnservedEndpoints(), 0)
        self.assertEquals(served, set("ABC"))
        for i in xrange(5-2):
            served = set()
            served.add(self.pts._serveReg("ABC").addr)
            served.add(self.pts._serveReg("ABC").addr)
            served.add(self.pts._serveReg("ABC").addr)
            self.assertEquals(served, set("ABC"))
        remaining = set("ABC")
        remaining.remove(self.pts._serveReg(remaining).addr)
        self.assertRaises(KeyError, self.pts._serveReg, "ABC")
        remaining.remove(self.pts._serveReg(remaining).addr)
        self.assertRaises(KeyError, self.pts._serveReg, "ABC")
        remaining.remove(self.pts._serveReg(remaining).addr)
        self.assertRaises(KeyError, self.pts._serveReg, "ABC")
        self.assertEquals(remaining, set())
        self.assertEquals(self.pts.getNumUnservedEndpoints(), 0)

    def test_match_normal(self):
        self.pts.addEndpoint("A", "a|p")
        self.pts2 = Endpoints(af=socket.AF_INET)
        self.pts2.addEndpoint("B", "a|p")
        self.pts2.addEndpoint("C", "b|p")
        self.pts2.addEndpoint("D", "a|q")
        expected = (Endpoint("A", Transport("a","p")), Endpoint("B", Transport("a","p")))
        empty = Endpoints.EMPTY_MATCH
        self.assertEquals(expected, Endpoints.match(self.pts, self.pts2, ["p"]))
        self.assertEquals(empty, Endpoints.match(self.pts, self.pts2, ["x"]))

    def test_match_unequal_client_server(self):
        self.pts.addEndpoint("A", "a|p")
        self.pts2 = Endpoints(af=socket.AF_INET)
        self.pts2.addEndpoint("B", "a|q")
        expected = (Endpoint("A", Transport("a","p")), Endpoint("B", Transport("a","q")))
        empty = Endpoints.EMPTY_MATCH
        self.assertEquals(expected, Endpoints.match(self.pts, self.pts2, ["p", "q"]))
        self.assertEquals(empty, Endpoints.match(self.pts, self.pts2, ["p"]))
        self.assertEquals(empty, Endpoints.match(self.pts, self.pts2, ["q"]))
        self.assertEquals(empty, Endpoints.match(self.pts, self.pts2, ["x"]))

    def test_match_raw_server(self):
        self.pts.addEndpoint("A", "p")
        self.pts2 = Endpoints(af=socket.AF_INET)
        self.pts2.addEndpoint("B", "p")
        expected = (Endpoint("A", Transport("","p")), Endpoint("B", Transport("","p")))
        empty = Endpoints.EMPTY_MATCH
        self.assertEquals(expected, Endpoints.match(self.pts, self.pts2, ["p"]))
        self.assertEquals(empty, Endpoints.match(self.pts, self.pts2, ["x"]))

    def test_match_many_inners(self):
        self.pts.addEndpoint("A", "a|p")
        self.pts.addEndpoint("B", "b|p")
        self.pts.addEndpoint("C", "p")
        self.pts2 = Endpoints(af=socket.AF_INET)
        self.pts2.addEndpoint("D", "a|p")
        self.pts2.addEndpoint("E", "b|p")
        self.pts2.addEndpoint("F", "p")
        # this test ensures we have a sane policy for selecting between inners pools
        expected = set()
        expected.add((Endpoint("A", Transport("a","p")), Endpoint("D", Transport("a","p"))))
        expected.add((Endpoint("B", Transport("b","p")), Endpoint("E", Transport("b","p"))))
        expected.add((Endpoint("C", Transport("","p")), Endpoint("F", Transport("","p"))))
        result = set()
        result.add(Endpoints.match(self.pts, self.pts2, ["p"]))
        result.add(Endpoints.match(self.pts, self.pts2, ["p"]))
        result.add(Endpoints.match(self.pts, self.pts2, ["p"]))
        empty = Endpoints.EMPTY_MATCH
        self.assertEquals(expected, result)
        self.assertEquals(empty, Endpoints.match(self.pts, self.pts2, ["x"]))
        self.assertEquals(empty, Endpoints.match(self.pts, self.pts2, ["x"]))
        self.assertEquals(empty, Endpoints.match(self.pts, self.pts2, ["x"]))

    def test_match_exhaustion(self):
        self.pts.addEndpoint("A", "p")
        self.pts2 = Endpoints(af=socket.AF_INET, maxserve=2)
        self.pts2.addEndpoint("B", "p")
        Endpoints.match(self.pts2, self.pts, ["p"])
        Endpoints.match(self.pts2, self.pts, ["p"])
        empty = Endpoints.EMPTY_MATCH
        self.assertTrue("B" not in self.pts2._endpoints)
        self.assertTrue("B" not in self.pts2._indexes["p"][""])
        self.assertEquals(empty, Endpoints.match(self.pts2, self.pts, ["p"]))


class FacilitatorTest(unittest.TestCase):

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

    def test_parse_relay_file(self):
        fp = StringIO()
        fp.write("websocket 0.0.1.0:1\n")
        fp.flush()
        fp.seek(0)
        af = socket.AF_INET
        servers = { af: Endpoints(af=af) }
        parse_relay_file(servers, fp)
        self.assertEquals(servers[af]._endpoints, {('0.0.1.0', 1): Transport('', 'websocket')})

class FacilitatorProcTest(unittest.TestCase):
    IPV4_CLIENT_ADDR = ("1.1.1.1", 9000)
    IPV6_CLIENT_ADDR = ("[11::11]", 9000)
    IPV4_PROXY_ADDR = ("2.2.2.2", 13000)
    IPV6_PROXY_ADDR = ("[22::22]", 13000)
    IPV4_RELAY_ADDR = ("0.0.1.0", 1)
    IPV6_RELAY_ADDR = ("[0:0::1:0]", 1)

    def gimme_socket(self):
        return gimme_socket(FACILITATOR_HOST, FACILITATOR_PORT)

    def setUp(self):
        self.relay_file = tempfile.NamedTemporaryFile()
        self.relay_file.write("%s %s\n" % (RELAY_TP, fac.format_addr(self.IPV4_RELAY_ADDR)))
        self.relay_file.write("%s %s\n" % (RELAY_TP, fac.format_addr(self.IPV6_RELAY_ADDR)))
        self.relay_file.flush()
        self.relay_file.seek(0)
        fn = os.path.join(os.path.dirname(__file__), "./facilitator")
        self.process = subprocess.Popen(["python", fn, "-d", "-p", str(FACILITATOR_PORT), "-r", self.relay_file.name, "-l", "/dev/null"])
        time.sleep(0.1)

    def tearDown(self):
        ret = self.process.poll()
        if ret is not None:
            raise Exception("facilitator subprocess exited unexpectedly with status %d" % ret)
        self.process.terminate()

    def test_timeout(self):
        """Test that the socket will not accept slow writes indefinitely.
        Successive sends should not reset the timeout counter."""
        s = self.gimme_socket()
        time.sleep(0.3)
        s.send("w")
        time.sleep(0.3)
        s.send("w")
        time.sleep(0.3)
        s.send("w")
        time.sleep(0.3)
        s.send("w")
        time.sleep(0.3)
        self.assertRaises(socket.error, s.send, "w")

    def test_readline_limit(self):
        """Test that reads won't buffer indefinitely."""
        s = self.gimme_socket()
        buflen = 0
        try:
            while buflen + 1024 < 200000:
                s.send("X" * 1024)
                buflen += 1024
            # TODO(dcf1): sometimes no error is raised, and this test fails
            self.fail("should have raised a socket error")
        except socket.error:
            pass

    def test_af_v4_v4(self):
        """Test that IPv4 proxies can get IPv4 clients."""
        fac.put_reg(FACILITATOR_ADDR, self.IPV4_CLIENT_ADDR, CLIENT_TP)
        fac.put_reg(FACILITATOR_ADDR, self.IPV6_CLIENT_ADDR, CLIENT_TP)
        reg = fac.get_reg(FACILITATOR_ADDR, self.IPV4_PROXY_ADDR, PROXY_TPS)
        self.assertEqual(reg["client"], fac.format_addr(self.IPV4_CLIENT_ADDR))

    def test_af_v4_v6(self):
        """Test that IPv4 proxies do not get IPv6 clients."""
        fac.put_reg(FACILITATOR_ADDR, self.IPV6_CLIENT_ADDR, CLIENT_TP)
        reg = fac.get_reg(FACILITATOR_ADDR, self.IPV4_PROXY_ADDR, PROXY_TPS)
        self.assertEqual(reg["client"], "")

    def test_af_v6_v4(self):
        """Test that IPv6 proxies do not get IPv4 clients."""
        fac.put_reg(FACILITATOR_ADDR, self.IPV4_CLIENT_ADDR, CLIENT_TP)
        reg = fac.get_reg(FACILITATOR_ADDR, self.IPV6_PROXY_ADDR, PROXY_TPS)
        self.assertEqual(reg["client"], "")

    def test_af_v6_v6(self):
        """Test that IPv6 proxies can get IPv6 clients."""
        fac.put_reg(FACILITATOR_ADDR, self.IPV4_CLIENT_ADDR, CLIENT_TP)
        fac.put_reg(FACILITATOR_ADDR, self.IPV6_CLIENT_ADDR, CLIENT_TP)
        reg = fac.get_reg(FACILITATOR_ADDR, self.IPV6_PROXY_ADDR, PROXY_TPS)
        self.assertEqual(reg["client"], fac.format_addr(self.IPV6_CLIENT_ADDR))

    def test_fields(self):
        """Test that facilitator responses contain all the required fields."""
        fac.put_reg(FACILITATOR_ADDR, self.IPV4_CLIENT_ADDR, CLIENT_TP)
        reg = fac.get_reg(FACILITATOR_ADDR, self.IPV4_PROXY_ADDR, PROXY_TPS)
        self.assertEqual(reg["client"], fac.format_addr(self.IPV4_CLIENT_ADDR))
        self.assertEqual(reg["client-transport"], CLIENT_TP)
        self.assertEqual(reg["relay"], fac.format_addr(self.IPV4_RELAY_ADDR))
        self.assertEqual(reg["relay-transport"], RELAY_TP)
        self.assertGreater(int(reg["check-back-in"]), 0)

#     def test_same_proxy(self):
#         """Test that the same proxy doesn't get the same client when asking
#         twice."""
#         self.fail()
#
#     def test_num_clients(self):
#         """Test that the same proxy can pick up up to five different clients but
#         no more. Test that a proxy ceasing to handle a client allows the proxy
#         to handle another, different client."""
#         self.fail()
#
#     def test_num_proxies(self):
#         """Test that a single client is handed out to five different proxies but
#         no more. Test that a proxy ceasing to handle a client reduces its count
#         so another proxy can handle it."""
#         self.fail()
#
#     def test_proxy_timeout(self):
#         """Test that a proxy ceasing to connect for some time period causes that
#         proxy's clients to be unhandled by that proxy."""
#         self.fail()
#
#     def test_localhost_only(self):
#         """Test that the facilitator doesn't listen on any external
#         addresses."""
#         self.fail()
#
#     def test_hostname(self):
#         """Test that the facilitator rejects hostnames."""
#         self.fail()

class ParseAddrSpecTest(unittest.TestCase):
    def test_ipv4(self):
        self.assertEqual(fac.parse_addr_spec("192.168.0.1:9999"), ("192.168.0.1", 9999))

    def test_ipv6(self):
        self.assertEqual(fac.parse_addr_spec("[12::34]:9999"), ("12::34", 9999))

    def test_defhost_defport_ipv4(self):
        self.assertEqual(fac.parse_addr_spec("192.168.0.2:8888", defhost="192.168.0.1", defport=9999), ("192.168.0.2", 8888))
        self.assertEqual(fac.parse_addr_spec("192.168.0.2:", defhost="192.168.0.1", defport=9999), ("192.168.0.2", 9999))
        self.assertEqual(fac.parse_addr_spec("192.168.0.2", defhost="192.168.0.1", defport=9999), ("192.168.0.2", 9999))
        self.assertEqual(fac.parse_addr_spec(":8888", defhost="192.168.0.1", defport=9999), ("192.168.0.1", 8888))
        self.assertEqual(fac.parse_addr_spec(":", defhost="192.168.0.1", defport=9999), ("192.168.0.1", 9999))
        self.assertEqual(fac.parse_addr_spec("", defhost="192.168.0.1", defport=9999), ("192.168.0.1", 9999))

    def test_defhost_defport_ipv6(self):
        self.assertEqual(fac.parse_addr_spec("[1234::2]:8888", defhost="1234::1", defport=9999), ("1234::2", 8888))
        self.assertEqual(fac.parse_addr_spec("[1234::2]:", defhost="1234::1", defport=9999), ("1234::2", 9999))
        self.assertEqual(fac.parse_addr_spec("[1234::2]", defhost="1234::1", defport=9999), ("1234::2", 9999))
        self.assertEqual(fac.parse_addr_spec(":8888", defhost="1234::1", defport=9999), ("1234::1", 8888))
        self.assertEqual(fac.parse_addr_spec(":", defhost="1234::1", defport=9999), ("1234::1", 9999))
        self.assertEqual(fac.parse_addr_spec("", defhost="1234::1", defport=9999), ("1234::1", 9999))

    def test_canonical_ip_noresolve(self):
        """Test that canonical_ip does not do DNS resolution by default."""
        self.assertRaises(ValueError, fac.canonical_ip, *fac.parse_addr_spec("example.com:80"))

class ParseTransactionTest(unittest.TestCase):
    def test_empty_string(self):
        self.assertRaises(ValueError, fac.parse_transaction, "")

    def test_correct(self):
        self.assertEqual(fac.parse_transaction("COMMAND"), ("COMMAND", ()))
        self.assertEqual(fac.parse_transaction("COMMAND X=\"\""), ("COMMAND", (("X", ""),)))
        self.assertEqual(fac.parse_transaction("COMMAND X=\"ABC\""), ("COMMAND", (("X", "ABC"),)))
        self.assertEqual(fac.parse_transaction("COMMAND X=\"\\A\\B\\C\""), ("COMMAND", (("X", "ABC"),)))
        self.assertEqual(fac.parse_transaction("COMMAND X=\"\\\\\\\"\""), ("COMMAND", (("X", "\\\""),)))
        self.assertEqual(fac.parse_transaction("COMMAND X=\"ABC\" Y=\"DEF\""), ("COMMAND", (("X", "ABC"), ("Y", "DEF"))))
        self.assertEqual(fac.parse_transaction("COMMAND KEY-NAME=\"ABC\""), ("COMMAND", (("KEY-NAME", "ABC"),)))
        self.assertEqual(fac.parse_transaction("COMMAND KEY_NAME=\"ABC\""), ("COMMAND", (("KEY_NAME", "ABC"),)))

    def test_missing_command(self):
        self.assertRaises(ValueError, fac.parse_transaction, "X=\"ABC\"")
        self.assertRaises(ValueError, fac.parse_transaction, " X=\"ABC\"")

    def test_missing_space(self):
        self.assertRaises(ValueError, fac.parse_transaction, "COMMAND/X=\"ABC\"")
        self.assertRaises(ValueError, fac.parse_transaction, "COMMAND X=\"ABC\"Y=\"DEF\"")

    def test_bad_quotes(self):
        self.assertRaises(ValueError, fac.parse_transaction, "COMMAND X=\"")
        self.assertRaises(ValueError, fac.parse_transaction, "COMMAND X=\"ABC")
        self.assertRaises(ValueError, fac.parse_transaction, "COMMAND X=\"ABC\" Y=\"ABC")
        self.assertRaises(ValueError, fac.parse_transaction, "COMMAND X=\"ABC\\")

    def test_truncated(self):
        self.assertRaises(ValueError, fac.parse_transaction, "COMMAND X=")

    def test_newline(self):
        self.assertRaises(ValueError, fac.parse_transaction, "COMMAND X=\"ABC\" \nY=\"DEF\"")

class ReadClientRegistrationsTest(unittest.TestCase):
    def testSingle(self):
        l = list(fac.read_client_registrations(""))
        self.assertEqual(len(l), 0)
        l = list(fac.read_client_registrations("client=1.2.3.4:1111"))
        self.assertEqual(len(l), 1)
        self.assertEqual(l[0].addr, ("1.2.3.4", 1111))
        l = list(fac.read_client_registrations("client=1.2.3.4:1111\n"))
        self.assertEqual(len(l), 1)
        self.assertEqual(l[0].addr, ("1.2.3.4", 1111))
        l = list(fac.read_client_registrations("foo=bar&client=1.2.3.4:1111&baz=quux"))
        self.assertEqual(len(l), 1)
        self.assertEqual(l[0].addr, ("1.2.3.4", 1111))
        l = list(fac.read_client_registrations("foo=b%3dar&client=1.2.3.4%3a1111"))
        self.assertEqual(len(l), 1)
        self.assertEqual(l[0].addr, ("1.2.3.4", 1111))
        l = list(fac.read_client_registrations("client=%5b1::2%5d:3333"))
        self.assertEqual(len(l), 1)
        self.assertEqual(l[0].addr, ("1::2", 3333))

    def testDefaultAddress(self):
        l = list(fac.read_client_registrations("client=:1111&transport=websocket", defhost="1.2.3.4"))
        self.assertEqual(l[0].addr, ("1.2.3.4", 1111))
        l = list(fac.read_client_registrations("client=1.2.3.4:&transport=websocket", defport=1111))
        self.assertEqual(l[0].addr, ("1.2.3.4", 1111))

    def testDefaultTransport(self):
        l = list(fac.read_client_registrations("client=1.2.3.4:1111"))
        self.assertEqual(l[0].transport, "websocket")

    def testMultiple(self):
        l = list(fac.read_client_registrations("client=1.2.3.4:1111&foo=bar\nfoo=bar&client=5.6.7.8:2222"))
        self.assertEqual(len(l), 2)
        self.assertEqual(l[0].addr, ("1.2.3.4", 1111))
        self.assertEqual(l[1].addr, ("5.6.7.8", 2222))
        l = list(fac.read_client_registrations("client=1.2.3.4:1111&foo=bar\nfoo=bar&client=%5b1::2%5d:3333"))
        self.assertEqual(len(l), 2)
        self.assertEqual(l[0].addr, ("1.2.3.4", 1111))
        self.assertEqual(l[1].addr, ("1::2", 3333))

    def testInvalid(self):
        # Missing "client".
        with self.assertRaises(ValueError):
            list(fac.read_client_registrations("foo=bar"))
        # More than one "client".
        with self.assertRaises(ValueError):
            list(fac.read_client_registrations("client=1.2.3.4:1111&foo=bar&client=5.6.7.8:2222"))
        # Single client with bad syntax.
        with self.assertRaises(ValueError):
            list(fac.read_client_registrations("client=1.2.3.4,1111"))

if __name__ == "__main__":
    unittest.main()
