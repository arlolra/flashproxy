#!/usr/bin/js

/* To run this test program, install the Rhino JavaScript interpreter
   (apt-get install rhino). */

var num_tests = 0;
var num_failed = 0;

load("flashproxy.js");

function objects_equal(a, b)
{
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

function quote(s)
{
    return "\"" + s.replace(/([\\\"])/, "\\$1") + "\"";
}

function maybe_quote(s)
{
    if (/[\\\"]/.test(s))
        return quote(s);
    else
        return s;
}

function repr(x)
{
    if (typeof x === null) {
        return "null";
    } else if (typeof x == "undefined") {
        return "undefined";
    } else if (typeof x == "object") {
        var elems = [];
        for (var k in x)
            elems.push(maybe_quote(k) + ": " + repr(x[k]));
        return "{ " + elems.join(", ") + " }";
    } else if (typeof x == "string") {
        return quote(x);
    } else {
        return x.toString();
    }
}

function pass(test)
{
    num_tests++;
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

test_parse_query_string();

if (num_failed == 0)
    quit(0);
else
    quit(1);
