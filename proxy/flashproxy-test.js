#!/usr/bin/env rhino

/* To run this test program, install the Rhino JavaScript interpreter
   (apt-get install rhino). */

var VERBOSE = false;
if ("-v" in arguments)
    VERBOSE = true;

var num_tests = 0;
var num_failed = 0;

var window = {location: {search: "?"}};
var document = {cookie: ""};

load("flashproxy.js");

function objects_equal(a, b) {
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
function announce(test_name) {
    if (VERBOSE) {
        if (!top)
            print();
        print(test_name);
    }
    top = false;
}

function pass(test) {
    num_tests++;
    if (VERBOSE)
        print("PASS " + repr(test));
}

function fail(test, expected, actual) {
    num_tests++;
    num_failed++;
    print("FAIL " + repr(test) + "  expected: " + repr(expected) + "  actual: " + repr(actual));
}

function test_build_url() {
    var TESTS = [
        { args: ["http", "example.com"],
          expected: "http://example.com" },
        { args: ["http", "example.com", 80],
          expected: "http://example.com" },
        { args: ["http", "example.com", 81],
          expected: "http://example.com:81" },
        { args: ["https", "example.com", 443],
          expected: "https://example.com" },
        { args: ["https", "example.com", 444],
          expected: "https://example.com:444" },
        { args: ["http", "example.com", 80, "/"],
          expected: "http://example.com/" },
        { args: ["http", "example.com", 80, "/test?k=%#v"],
          expected: "http://example.com/test%3Fk%3D%25%23v" },
        { args: ["http", "example.com", 80, "/test", []],
          expected: "http://example.com/test?" },
        { args: ["http", "example.com", 80, "/test", [["k", "%#v"]]],
          expected: "http://example.com/test?k=%25%23v" },
        { args: ["http", "example.com", 80, "/test", [["a", "b"], ["c", "d"]]],
          expected: "http://example.com/test?a=b&c=d" },
        { args: ["http", "1.2.3.4"],
          expected: "http://1.2.3.4" },
        { args: ["http", "1:2::3:4"],
          expected: "http://[1:2::3:4]" },
        { args: ["http", "bog][us"],
          expected: "http://bog%5D%5Bus" },
        { args: ["http", "bog:u]s"],
          expected: "http://bog%3Au%5Ds" },
    ];

    announce("test_build_url");
    for (var i = 0; i < TESTS.length; i++) {
        var test = TESTS[i];
        var actual;

        actual = build_url.apply(undefined, test.args);
        if (objects_equal(actual, test.expected))
            pass(test.args);
        else
            fail(test.args, test.expected, actual);
    }
}

/* This test only checks that things work for strings
   formatted like document.cookie. Browsers maintain
   several properties about this string, for example
   cookie names are unique with no trailing whitespace.
   See http://www.ietf.org/rfc/rfc2965.txt for the grammar. */
function test_parse_cookie_string() {
    var TESTS = [
        { cs: "",
          expected: { } },
        { cs: "a=b",
          expected: { a: "b"} },
        { cs: "a=b=c",
          expected: { a: "b=c"} },
        { cs: "a=b; c=d",
          expected: { a: "b", c: "d" } },
        { cs: "a=b ; c=d",
          expected: { a: "b", c: "d" } },
        { cs: "a= b",
          expected: {a: "b" } },
        { cs: "a=",
          expected: { a: "" } },
        { cs: "key",
          expected: null },
        { cs: "key=%26%20",
          expected: { key: "& " } },
        { cs: "a=\"\"",
          expected: { a: "\"\"" } },
    ];

    announce("test_parse_cookie_string");
    for (var i = 0; i < TESTS.length; i++) {
        var test = TESTS[i];
        var actual;

        actual = parse_cookie_string(test.cs);
        if (objects_equal(actual, test.expected))
            pass(test.cs);
        else
            fail(test.cs, test.expected, actual);
    }
}

function test_parse_query_string() {
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

function test_get_param_boolean() {
    var TESTS = [
        { qs: "param=true",
          expected: true },
        { qs: "param",
          expected: true },
        { qs: "param=",
          expected: true },
        { qs: "param=1",
          expected: true },
        { qs: "param=0",
          expected: false },
        { qs: "param=false",
          expected: false },
        { qs: "param=unexpected",
          expected: null },
        { qs: "pram=true",
          expected: false },
    ];

    announce("test_get_param_boolean");
    for (var i = 0; i < TESTS.length; i++) {
        var test = TESTS[i];
        var actual;
        var query;

        query = parse_query_string(test.qs);
        actual = get_param_boolean(query, "param", false);
        if (objects_equal(actual, test.expected))
            pass(test.qs);
        else
            fail(test.qs, test.expected, actual);
    }
}

function test_parse_addr_spec() {
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
        { spec: "[1:2::a:f]:4444",
          expected: { host: "1:2::a:f", port: 4444 } },
        { spec: "[1:2::a:f]",
          expected: null },
        { spec: "[1:2::a:f]:0x1111",
          expected: null },
        { spec: "[1:2::a:f]:-4444",
          expected: null },
        { spec: "[1:2::a:f]:65536",
          expected: null },
        { spec: "[1:2::ffff:1.2.3.4]:4444",
          expected: { host: "1:2::ffff:1.2.3.4", port: 4444 } },
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

function test_get_param_addr() {
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

    announce("test_get_param_addr");
    for (var i = 0; i < TESTS.length; i++) {
        var test = TESTS[i];
        var actual;

        actual = get_param_addr(test.query, "addr", DEFAULT);
        if (objects_equal(actual, test.expected))
            pass(test.query);
        else
            fail(test.query, test.expected, actual);
    }
}

function test_lang_keys() {
    var TESTS = [
        { code: "de", expected: ["de"] },
        { code: "DE", expected: ["de"] },
        { code: "de-at", expected: ["de-at", "de"] },
        { code: "de-AT", expected: ["de-at", "de"] },
    ];
    for (var i = 0; i < TESTS.length; i++) {
        var test = TESTS[i];
        var actual = lang_keys(test.code);

        var j, k;
        k = 0;
        for (j = 0; j < test.expected.length; j++) {
            for (; k < actual.length; k++) {
                if (test.expected[j] === actual[k])
                    break;
            }
            if (k === actual.length)
                fail(test.code, test.expected, actual)
        }
    }
}

function test_have_websocket_binary_frames() {
    var TESTS = [
        { ua: "Mozilla/5.0 (Macintosh; Intel Mac OS X 10.8; rv:10.0.2) Gecko/20100101 Firefox/10.0.2", expected: false },
        { ua: "Mozilla/5.0 (Macintosh; Intel Mac OS X 10.8; rv:11.0) Gecko/20100101 Firefox/11.0", expected: true },
        { ua: "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_8_4) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/27.0.1453.110 Safari/537.36", expected: true },
        { ua: "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_8_4) AppleWebKit/536.30.1 (KHTML, like Gecko) Version/6.0.5 Safari/536.30.1", expected: true },
        { expected: false },  // no userAgent
    ];
    var _navigator = window.navigator;
    for (var i = 0; i < TESTS.length; i++) {
        var test = TESTS[i];
        window.navigator = { userAgent: test.ua };
        var actual = have_websocket_binary_frames();

        if (objects_equal(actual, test.expected))
            pass(test.ua);
        else
            fail(test.ua, test.expected, actual);
    }
    window.navigator = _navigator;
}

test_build_url();
test_parse_cookie_string();
test_parse_query_string();
test_get_param_boolean();
test_parse_addr_spec();
test_get_param_addr();
test_lang_keys();
test_have_websocket_binary_frames();

if (num_failed == 0)
    quit(0);
else
    quit(1);
