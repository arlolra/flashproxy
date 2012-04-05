#!/usr/bin/js

/* To run this test program, install the Rhino JavaScript interpreter
   (apt-get install rhino). */

var VERBOSE = false;
if ("-v" in arguments)
    VERBOSE = true;

var num_tests = 0;
var num_failed = 0;

var window = {location: {search: "?"}};

load("flashproxy.js");

function objects_equal(a, b)
{
    if ((a === null) != (b === null))
        return false;
    if (typeof a != typeof b)
        return false;
    if (typeof a != "object")
        return a == b;

    for (var k in a) {
        if (!objects_equal(a[k], b[k]))
            return false;
    }
    for (var k in b) {
        if (!objects_equal(a[k], b[k]))
            return false;
    }

    return true;
}

var top = true;
function announce(test_name)
{
    if (VERBOSE) {
        if (!top)
            print();
        print(test_name);
    }
    top = false;
}

function pass(test)
{
    num_tests++;
    if (VERBOSE)
        print("PASS " + repr(test));
}

function fail(test, expected, actual)
{
    num_tests++;
    num_failed++;
    print("FAIL " + repr(test) + "  expected: " + repr(expected) + "  actual: " + repr(actual));
}

function test_parse_query_string()
{
    var TESTS = [
        { qs: "",
          expected: { } },
        { qs: "a=b",
          expected: { a: "b" } },
        { qs: "a=b=c",
          expected: { a: "b=c" } },
        { qs: "a=b&c=d",
          expected: { a: "b", c: "d" } },
        { qs: "client=&relay=1.2.3.4%3A9001",
          expected: { client: "", relay: "1.2.3.4:9001" } },
        { qs: "a=b%26c=d",
          expected: { a: "b&c=d" } },
        { qs: "a%3db=d",
          expected: { "a=b": "d" } },
        { qs: "a=b+c%20d",
          expected: { "a": "b c d" } },
        { qs: "a=b+c%2bd",
          expected: { "a": "b c+d" } },
        { qs: "a+b=c",
          expected: { "a b": "c" } },
        { qs: "a=b+c+d",
          expected: { a: "b c d" } },
        /* First appearance wins. */
        { qs: "a=b&c=d&a=e",
          expected: { a: "b", c: "d" } },
        { qs: "a",
          expected: { a: "" } },
        { qs: "=b",
          expected: { "": "b" } },
        { qs: "&a=b",
          expected: { "": "", a: "b" } },
        { qs: "a=b&",
          expected: { "": "", a: "b" } },
        { qs: "a=b&&c=d",
          expected: { "": "", a: "b", c: "d" } },
    ];

    announce("test_parse_query_string");
    for (var i = 0; i < TESTS.length; i++) {
        var test = TESTS[i];
        var actual;

        actual = parse_query_string(test.qs);
        if (objects_equal(actual, test.expected))
            pass(test.qs);
        else
            fail(test.qs, test.expected, actual);
    }
}

function test_parse_addr_spec()
{
    var TESTS = [
        { spec: "",
          expected: null },
        { spec: "3.3.3.3:4444",
          expected: { host: "3.3.3.3", port: 4444 } },
        { spec: "3.3.3.3",
          expected: null },
        { spec: "3.3.3.3:0x1111",
          expected: null },
        { spec: "3.3.3.3:-4444",
          expected: null },
        { spec: "3.3.3.3:65536",
          expected: null },
    ];

    announce("test_parse_addr_spec");
    for (var i = 0; i < TESTS.length; i++) {
        var test = TESTS[i];
        var actual;

        actual = parse_addr_spec(test.spec);
        if (objects_equal(actual, test.expected))
            pass(test.spec);
        else
            fail(test.spec, test.expected, actual);
    }
}

function test_get_query_param_addr()
{
    var DEFAULT = { host: "1.1.1.1", port: 2222 };
    var TESTS = [
        { query: { },
          expected: DEFAULT },
        { query: { addr: "3.3.3.3:4444" },
          expected: { host: "3.3.3.3", port: 4444 } },
        { query: { x: "3.3.3.3:4444" },
          expected: DEFAULT },
        { query: { addr: "---" },
          expected: null },
    ];

    announce("test_get_query_param_addr");
    for (var i = 0; i < TESTS.length; i++) {
        var test = TESTS[i];
        var actual;

        actual = get_query_param_addr(test.query, "addr", DEFAULT);
        if (objects_equal(actual, test.expected))
            pass(test.query);
        else
            fail(test.query, test.expected, actual);
    }
}

test_parse_query_string();
test_parse_addr_spec();
test_get_query_param_addr();

if (num_failed == 0)
    quit(0);
else
    quit(1);
