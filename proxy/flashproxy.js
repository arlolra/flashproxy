/* Query string parameters. These change how the program runs from the outside.
 * For example:
 *   http://www.example.com/embed.html?facilitator=http://127.0.0.1:9002&debug=1
 *
 * client=<HOST>:<PORT>
 * The address of the client to connect to. The proxy normally receives this
 * information from the facilitator. When this option is used, the facilitator
 * query is not done. The "relay" parameter must be given as well.
 *
 * debug=0|1
 * If true, show verbose terminal-like output instead of the badge. The values
 * "1", "true", and the empty string "" all enable debug mode. Any other value
 * uses the normal badge display.
 *
 * cookierequired=0|1
 * If true, the proxy will disable itself if the user has not explicitly opted
 * in by setting a cookie through the options page. If absent or false, the proxy
 * will run unless the user has explicitly opted out.
 *
 * facilitator=https://host:port/
 * The URL of the facilitator CGI script. By default it is
 * DEFAULT_FACILITATOR_URL.
 *
 * facilitator_poll_interval=<FLOAT>
 * How often to poll the facilitator, in seconds. The default is
 * DEFAULT_FACILITATOR_POLL_INTERVAL. There is a sanity-check minimum of 1.0 s.
 *
 * initial_facilitator_poll_interval=<FLOAT>
 * How long to wait before polling the facilitator the first time, in seconds.
 * DEFAULT_INITIAL_FACILITATOR_POLL_INTERVAL.
 *
 * max_clients=<NUM>
 * How many clients to serve concurrently. The default is
 * DEFAULT_MAX_NUM_PROXY_PAIRS.
 *
 * relay=<HOST>:<PORT>
 * The address of the relay to connect to. The proxy normally receives this
 * information from the facilitator. When this option is used, the facilitator
 * query is not done. The "client" parameter must be given as well.
 *
 * ratelimit=<FLOAT>(<UNIT>)?|off
 * What rate to limit all proxy traffic combined to. The special value "off"
 * disables the limit. The default is DEFAULT_RATE_LIMIT. There is a
 * sanity-check minimum of "10K".
 */

/* WebSocket links.
 *
 * The WebSocket Protocol
 * https://tools.ietf.org/html/rfc6455
 *
 * The WebSocket API
 * http://dev.w3.org/html5/websockets/
 *
 * MDN page with browser compatibility
 * https://developer.mozilla.org/en/WebSockets
 *
 * Implementation tests (including tests of binary messages)
 * http://autobahn.ws/testsuite/reports/clients/index.html
 */

var DEFAULT_FACILITATOR_URL = "https://tor-facilitator.bamsoftware.com/";

var DEFAULT_MAX_NUM_PROXY_PAIRS = 10;

var DEFAULT_INITIAL_FACILITATOR_POLL_INTERVAL = 60.0;
var DEFAULT_FACILITATOR_POLL_INTERVAL = 3600.0;
var MIN_FACILITATOR_POLL_INTERVAL = 10.0;

/* Bytes per second. Set to undefined to disable limit. */
var DEFAULT_RATE_LIMIT = undefined;
var MIN_RATE_LIMIT = 10 * 1024;
var RATE_LIMIT_HISTORY = 5.0;

/* Name of cookie that controls opt-in/opt-out. */
var OPT_IN_COOKIE = "flashproxy-allow";

/* Firefox before version 11.0 uses the name MozWebSocket. Whether the global
   variable WebSocket is defined indicates whether WebSocket is supported at
   all. */
var WebSocket = window.WebSocket || window.MozWebSocket;

var query = parse_query_string(window.location.search.substr(1));
var cookies = parse_cookie_string(document.cookie);
var DEBUG = get_param_boolean(query, "debug", false);
var debug_div;

if (DEBUG) {
    debug_div = document.createElement("pre");
    debug_div.className = "debug";
}

function puts(s) {
    if (debug_div) {
        var at_bottom;

        /* This shows up in the Web Console in Firefox and F12 developer tools
           in Internet Explorer. */
        (console.debug || console.log).call(console, s);

        /* http://www.w3.org/TR/cssom-view/#element-scrolling-members */
        at_bottom = (debug_div.scrollTop + debug_div.clientHeight === debug_div.scrollHeight);
        debug_div.appendChild(document.createTextNode(s + "\n"));
        if (at_bottom)
            debug_div.scrollTop = debug_div.scrollHeight;
    }
}

/* Parse a cookie data string (usually document.cookie). The return type
   is an object mapping cookies names to values. Returns null on error.

   http://www.w3.org/TR/DOM-Level-2-HTML/html.html#ID-8747038 */
function parse_cookie_string(cookies) {
    var strings;
    var result;

    result = {};
    if (cookies)
        strings = cookies.split(";");
    else
        strings = [];
    for (var i = 0; i < strings.length; i++) {
        var string = strings[i];
        var j, name, value;

        j = string.indexOf("=");
        if (j === -1) {
            return null;
        }
        name = decodeURIComponent(string.substr(0, j).trim());
        value = decodeURIComponent(string.substr(j + 1).trim());

        if (!(name in result))
             result[name] = value;
    }

    return result;
}

/* Parse a URL query string or application/x-www-form-urlencoded body. The
   return type is an object mapping string keys to string values. By design,
   this function doesn't support multiple values for the same named parameter,
   for example "a=1&a=2&a=3"; the first definition always wins. Returns null on
   error.

   Always decodes from UTF-8, not any other encoding.

   http://dev.w3.org/html5/spec/Overview.html#url-encoded-form-data */
function parse_query_string(qs) {
    var strings;
    var result;

    result = {};
    if (qs)
        strings = qs.split("&");
    else
        strings = [];
    for (var i = 0; i < strings.length; i++) {
        var string = strings[i];
        var j, name, value;

        j = string.indexOf("=");
        if (j === -1) {
            name = string;
            value = "";
        } else {
            name = string.substr(0, j);
            value = string.substr(j + 1);
        }
        name = decodeURIComponent(name.replace(/\+/g, " "));
        value = decodeURIComponent(value.replace(/\+/g, " "));
        if (!(name in result))
             result[name] = value;
    }

    return result;
}

/* params is a list of (key, value) 2-tuples. */
function build_query_string(params) {
    var parts = [];
    for (var i = 0; i < params.length; i++) {
        parts.push(encodeURIComponent(params[i][0]) + "=" + encodeURIComponent(params[i][1]));
    }
    return parts.join("&");
}

var DEFAULT_PORTS = {
    http: 80,
    https: 443
}
/* Build an escaped URL string from unescaped components. Only scheme and host
   are required. See RFC 3986, section 3. */
function build_url(scheme, host, port, path, params) {
    var parts = []

    parts.push(encodeURIComponent(scheme));
    parts.push("://");

    /* If it contains a colon but no square brackets, treat it like an IPv6
       address. */
    if (host.match(/:/) && !host.match(/[[\]]/)) {
        parts.push("[");
        parts.push(host);
        parts.push("]");
    } else {
        parts.push(encodeURIComponent(host));
    }
    if (port !== undefined && port !== DEFAULT_PORTS[scheme]) {
        parts.push(":");
        parts.push(encodeURIComponent(port.toString()));
    }

    if (path !== undefined && path !== "") {
        if (!path.match(/^\//))
            path = "/" + path;
        /* Slash is significant so we must protect it from encodeURIComponent,
           while still encoding question mark and number sign. RFC 3986, section
           3.3: "The path is terminated by the first question mark ('?') or
           number sign ('#') character, or by the end of the URI. ... A path
           consists of a sequence of path segments separated by a slash ('/')
           character." */
        path = path.replace(/[^\/]+/, function(m) {
            return encodeURIComponent(m);
        });
        parts.push(path);
    }

    if (params !== undefined) {
        parts.push("?");
        parts.push(build_query_string(params));
    }

    return parts.join("");
}

/* Get an object value and return it as a boolean. True values are "1", "true",
   and "". False values are "0" and "false". Any other value causes the function
   to return null (effectively false). Returns default_val if param is not a
   key.

   The empty string is true so that URLs like http://example.com/?debug will
   enable debug mode. */
function get_param_boolean(query, param, default_val) {
    var val;

    val = query[param];
    if (val === undefined)
        return default_val;
    else if (val === "true" || val === "1" || val === "")
        return true;
    else if (val === "false" || val === "0")
        return false;
    else
        return null;
}

/* Get an object value and return it as a string. Returns default_val if param
   is not a key. */
function get_param_string(query, param, default_val) {
    var val;

    val = query[param];
    if (val === undefined)
        return default_val;
    else
        return val;
}

/* Get an object value and parse it as an address spec. Returns default_val if
   param is not a key. Returns null on a parsing error. */
function get_param_addr(query, param, default_val) {
    var val;

    val = query[param];
    if (val === undefined)
        return default_val;
    else
        return parse_addr_spec(val);
}

/* Get an object value and parse it as an integer. Returns default_val if param
   is not a key. Return null on a parsing error. */
function get_param_integer(query, param, default_val) {
    var spec;
    var val;

    spec = query[param];
    if (spec === undefined) {
        return default_val;
    } else if (!spec.match(/^-?[0-9]+/)) {
        return null;
    } else {
        val = parseInt(spec, 10);
        if (isNaN(val))
            return null;
        else
            return val;
    }
}

/* Get an object value and parse it as a real number. Returns default_val if
   param is not a key. Return null on a parsing error. */
function get_param_number(query, param, default_val) {
    var spec;
    var val;

    spec = query[param];
    if (spec === undefined) {
        return default_val;
    } else {
        val = Number(spec);
        if (isNaN(val))
            return null;
        else
            return val;
    }
}

/* Get a floating-point number of seconds from a time specification. The only
   time specification format is a decimal number of seconds. Returns null on
   error. */
function get_param_timespec(query, param, default_val) {
    return get_param_number(query, param, default_val);
}

/* Parse a count of bytes. A suffix of "k", "m", or "g" (or uppercase)
   does what you would think. Returns null on error. */
function parse_byte_count(spec) {
    var UNITS = {
        k: 1024, m: 1024 * 1024, g: 1024 * 1024 * 1024,
        K: 1024, M: 1024 * 1024, G: 1024 * 1024 * 1024
    };
    var count, units;
    var matches;

    matches = spec.match(/^(\d+(?:\.\d*)?)(\w*)$/);
    if (matches === null)
        return null;

    count = Number(matches[1]);
    if (isNaN(count))
        return null;

    if (matches[2] === "") {
        units = 1;
    } else {
        units = UNITS[matches[2]];
        if (units === null)
            return null;
    }

    return count * Number(units);
}

/* Get an object value and parse it as a byte count. Example byte counts are
   "100" and "1.3m". Returns default_val if param is not a key. Return null on a
   parsing error. */
function get_param_byte_count(query, param, default_val) {
    var spec;

    spec = query[param];
    if (spec === undefined)
        return default_val;
    else
        return parse_byte_count(spec);
}

/* Parse an address in the form "host:port". Returns an Object with
   keys "host" (String) and "port" (int). Returns null on error. */
function parse_addr_spec(spec) {
    var m, host, port;

    m = null;
    /* IPv6 syntax. */
    if (!m)
        m = spec.match(/^\[([\0-9a-fA-F:.]+)\]:([0-9]+)$/);
    /* IPv4 syntax. */
    if (!m)
        m = spec.match(/^([0-9.]+):([0-9]+)$/);
    if (!m)
        return null;
    host = m[1];
    port = parseInt(m[2], 10);
    if (isNaN(port) || port < 0 || port > 65535)
        return null;

    return { host: host, port: port }
}

function format_addr(addr) {
    return addr.host + ":" + addr.port;
}

/* Does the WebSocket implementation in this browser support binary frames? (RFC
   6455 section 5.6.) If not, we have to use base64-encoded text frames. It is
   assumed that the client and relay endpoints always support binary frames. */
function have_websocket_binary_frames() {
    var ua, matches;

    ua = window.navigator.userAgent;
    if (ua === null)
        return false;

    /* We are cool for Chrome 16 or Safari 6.0. */

    matches = ua.match(/\bchrome\/(\d+)/i);
    if (matches !== null && Number(matches[1]) >= 16)
        return true;

    matches = ua.match(/\bversion\/(\d+)/i);
    if (ua.match(/\bsafari\b/i) && !ua.match(/\bchrome\b/i)
        && Number(matches[1]) >= 6)
        return true;

    return false;
}

function make_websocket(addr) {
    var url;
    var ws;

    url = build_url("ws", addr.host, addr.port, "/");

    if (have_websocket_binary_frames())
        ws = new WebSocket(url);
    else
        ws = new WebSocket(url, "base64");
    /* "User agents can use this as a hint for how to handle incoming binary
       data: if the attribute is set to 'blob', it is safe to spool it to disk,
       and if it is set to 'arraybuffer', it is likely more efficient to keep
       the data in memory." */
    ws.binaryType = "arraybuffer";

    return ws;
}

function FlashProxy() {
    if (DEBUG) {
        this.badge_elem = debug_div;
    } else {
        this.badge = new Badge();
        this.badge_elem = this.badge.elem;
    }
    this.badge_elem.setAttribute("id", "flashproxy-badge");

    this.proxy_pairs = [];

    this.start = function() {
        var client_addr;
        var relay_addr;
        var rate_limit_bytes;

        this.fac_url = get_param_string(query, "facilitator", DEFAULT_FACILITATOR_URL);

        this.max_num_proxy_pairs = get_param_integer(query, "max_clients", DEFAULT_MAX_NUM_PROXY_PAIRS);
        if (this.max_num_proxy_pairs === null || this.max_num_proxy_pairs < 0) {
            puts("Error: max_clients must be a nonnegative integer.");
            this.die();
            return;
        }

        this.initial_facilitator_poll_interval = get_param_timespec(query, "initial_facilitator_poll_interval", DEFAULT_INITIAL_FACILITATOR_POLL_INTERVAL);
        if (this.initial_facilitator_poll_interval === null || this.initial_facilitator_poll_interval < 0) {
            puts("Error: initial_facilitator_poll_interval must be a nonnegative number.");
            this.die();
            return;
        }

        this.facilitator_poll_interval = get_param_timespec(query, "facilitator_poll_interval");
        if (this.facilitator_poll_interval !== undefined && (this.facilitator_poll_interval === null || this.facilitator_poll_interval < MIN_FACILITATOR_POLL_INTERVAL)) {
            puts("Error: facilitator_poll_interval must be a nonnegative number at least " + MIN_FACILITATOR_POLL_INTERVAL + ".");
            this.die();
            return;
        }

        if (query["ratelimit"] === "off")
            rate_limit_bytes = undefined;
        else
            rate_limit_bytes = get_param_byte_count(query, "ratelimit", DEFAULT_RATE_LIMIT);
        if (rate_limit_bytes === undefined) {
            this.rate_limit = new DummyRateLimit();
        } else if (rate_limit_bytes === null || rate_limit_bytes < MIN_FACILITATOR_POLL_INTERVAL) {
            puts("Error: ratelimit must be a nonnegative number at least " + MIN_RATE_LIMIT + ".");
            this.die();
            return;
        } else {
            this.rate_limit = new BucketRateLimit(rate_limit_bytes * RATE_LIMIT_HISTORY, RATE_LIMIT_HISTORY);
        }

        client_addr = get_param_addr(query, "client");
        if (client_addr === null) {
            puts("Error: can't parse \"client\" parameter.");
            this.die();
            return;
        }
        relay_addr = get_param_addr(query, "relay");
        if (relay_addr === null) {
            puts("Error: can't parse \"relay\" parameter.");
            this.die();
            return;
        }
        if (client_addr !== undefined && relay_addr !== undefined) {
            this.begin_proxy(client_addr, relay_addr);
        } else if (client_addr !== undefined) {
            puts("Error: the \"client\" parameter requires \"relay\" also.")
            this.die();
            return;
        } else if (relay_addr !== undefined) {
            puts("Error: the \"relay\" parameter requires \"client\" also.")
            this.die();
            return;
        }

        puts("Starting; will contact facilitator in " + this.initial_facilitator_poll_interval + " seconds.");
        setTimeout(this.proxy_main.bind(this), this.initial_facilitator_poll_interval * 1000);
    };

    this.proxy_main = function() {
        var xhr;

        if (this.proxy_pairs.length >= this.max_num_proxy_pairs) {
            setTimeout(this.proxy_main.bind(this), this.facilitator_poll_interval * 1000);
            return;
        }

        xhr = new XMLHttpRequest();
        try {
            xhr.open("GET", this.fac_url);
        } catch (err) {
            /* An exception happens here when, for example, NoScript allows the
               domain on which the proxy badge runs, but not the domain to which
               it's trying to make the HTTP request. The exception message is
               like "Component returned failure code: 0x805e0006
               [nsIXMLHttpRequest.open]" on Firefox. */
            puts("Facilitator: exception while connecting: " + repr(err.message) + ".");
            this.die();
            return;
        }
        xhr.responseType = "text";
        xhr.onreadystatechange = function() {
            if (xhr.readyState === xhr.DONE) {
                if (xhr.status === 200)
                    this.fac_complete(xhr.responseText);
                else
                    puts("Facilitator: can't connect: got status " + repr(xhr.status) + " and status text " + repr(xhr.statusText) + ".");
            }
        }.bind(this);
        puts("Facilitator: connecting to " + this.fac_url + ".");
        xhr.send(null);
    };

    this.fac_complete = function(text) {
        var response;
        var client_addr;
        var relay_addr;
        var poll_interval;

        response = parse_query_string(text);

        if (this.facilitator_poll_interval) {
            poll_interval = this.facilitator_poll_interval;
        } else {
            poll_interval = get_param_integer(response, "check-back-in", DEFAULT_FACILITATOR_POLL_INTERVAL);
            if (poll_interval === null) {
                puts("Error: can't parse polling interval from facilitator, " + repr(poll_interval) + ".");
                poll_interval = DEFAULT_FACILITATOR_POLL_INTERVAL;
            }
            if (poll_interval < MIN_FACILITATOR_POLL_INTERVAL)
                poll_interval = MIN_FACILITATOR_POLL_INTERVAL;
        }

        puts("Next check in " + repr(poll_interval) + " seconds.");
        setTimeout(this.proxy_main.bind(this), poll_interval * 1000);

        if (!response.client) {
            puts("No clients.");
            return;
        }
        client_addr = parse_addr_spec(response.client);
        if (client_addr === null) {
            puts("Error: can't parse client spec " + repr(response.client) + ".");
            return;
        }
        if (!response.relay) {
            puts("Error: missing relay in response.");
            return;
        }
        relay_addr = parse_addr_spec(response.relay);
        if (relay_addr === null) {
            puts("Error: can't parse relay spec " + repr(response.relay) + ".");
            return;
        }
        puts("Facilitator: got client:" + repr(client_addr) + " "
            + "relay:" + repr(relay_addr) + ".");

        this.begin_proxy(client_addr, relay_addr);
    };

    this.begin_proxy = function(client_addr, relay_addr) {
        /* Start two proxy connections because of some versions of Tor making
           two pt connections:
           https://lists.torproject.org/pipermail/tor-dev/2012-December/004221.html */
        this.make_proxy_pair(client_addr, relay_addr);
        this.make_proxy_pair(client_addr, relay_addr);
    };

    this.make_proxy_pair = function(client_addr, relay_addr) {
        var proxy_pair;

        proxy_pair = new ProxyPair(client_addr, relay_addr, this.rate_limit);
        this.proxy_pairs.push(proxy_pair);
        proxy_pair.complete_callback = function(event) {
            puts("Complete.");
            /* Delete from the list of active proxy pairs. */
            this.proxy_pairs.splice(this.proxy_pairs.indexOf(proxy_pair), 1);
            if (this.badge)
                this.badge.proxy_end();
        }.bind(this);
        try {
            proxy_pair.connect();
        } catch (err) {
            puts("ProxyPair: exception while connecting: " + repr(err.message) + ".");
            this.die();
            return;
        }

        if (this.badge)
            this.badge.proxy_begin();
    };

    /* Cease all network operations and prevent any future ones. */
    this.disable = function() {
        puts("Disabling.");
        this.start = function() { };
        this.proxy_main = function() { };
        this.make_proxy_pair = function(client_addr, relay_addr) { };
        while (this.proxy_pairs.length > 0)
            this.proxy_pairs.pop().close();
        if (this.badge)
            this.badge.disable();
    };

    this.die = function() {
        puts("Dying.");
        if (this.badge)
            this.badge.die();
    };
}

/* An instance of a client-relay connection. */
function ProxyPair(client_addr, relay_addr, rate_limit) {
    var MAX_BUFFER = 10 * 1024 * 1024;

    function log(s)
    {
        puts(s)
    }

    this.client_addr = client_addr;
    this.relay_addr = relay_addr;
    this.rate_limit = rate_limit;

    this.c2r_schedule = [];
    this.r2c_schedule = [];

    this.running = true;
    this.flush_timeout_id = null;

    /* This callback function can be overridden by external callers. */
    this.complete_callback = function() {
    };

    /* Return a function that shows an error message and closes the other
       half of a communication pair. */
    this.make_onerror_callback = function(partner)
    {
        return function(event) {
            var ws = event.target;

            log(ws.label + ": error.");
            partner.close();
        }.bind(this);
    };

    this.onopen_callback = function(event) {
        var ws = event.target;

        log(ws.label + ": connected.");
    }.bind(this);

    this.onclose_callback = function(event) {
        var ws = event.target;

        log(ws.label + ": closed.");
        this.flush();

        if (this.running && is_closed(this.client_s) && is_closed(this.relay_s)) {
            this.running = false;
            this.complete_callback();
        }
    }.bind(this);

    this.onmessage_client_to_relay = function(event) {
        this.c2r_schedule.push(event.data);
        this.flush();
    }.bind(this);

    this.onmessage_relay_to_client = function(event) {
        this.r2c_schedule.push(event.data);
        this.flush();
    }.bind(this);

    this.connect = function() {
        log("Client: connecting.");
        this.client_s = make_websocket(this.client_addr);

        log("Relay: connecting.");
        this.relay_s = make_websocket(this.relay_addr);

        this.client_s.label = "Client";
        this.client_s.onopen = this.onopen_callback;
        this.client_s.onclose = this.onclose_callback;
        this.client_s.onerror = this.make_onerror_callback(this.relay_s);
        this.client_s.onmessage = this.onmessage_client_to_relay;

        this.relay_s.label = "Relay";
        this.relay_s.onopen = this.onopen_callback;
        this.relay_s.onclose = this.onclose_callback;
        this.relay_s.onerror = this.make_onerror_callback(this.client_s);
        this.relay_s.onmessage = this.onmessage_relay_to_client;
    };

    function is_open(ws)
    {
        return ws.readyState === ws.OPEN;
    }

    function is_closed(ws)
    {
        return ws.readyState === ws.CLOSED;
    }

    this.close = function() {
        this.client_s.close();
        this.relay_s.close();
    };

    /* Send as much data as the rate limit currently allows. */
    this.flush = function() {
        var busy;

        if (this.flush_timeout_id)
            clearTimeout(this.flush_timeout_id);
        this.flush_timeout_id = null;

        busy = true;
        while (busy && !this.rate_limit.is_limited()) {
            var chunk;

            busy = false;
            if (is_open(this.client_s) && this.client_s.bufferedAmount < MAX_BUFFER && this.r2c_schedule.length > 0) {
                chunk = this.r2c_schedule.shift();
                this.rate_limit.update(chunk.length);
                this.client_s.send(chunk);
                busy = true;
            }
            if (is_open(this.relay_s) && this.relay_s.bufferedAmount < MAX_BUFFER && this.c2r_schedule.length > 0) {
                chunk = this.c2r_schedule.shift();
                this.rate_limit.update(chunk.length);
                this.relay_s.send(chunk);
                busy = true;
            }
        }

        if (is_closed(this.relay_s) && !is_closed(this.client_s) && this.client_s.bufferedAmount === 0 && this.r2c_schedule.length === 0) {
            log("Client: closing.");
            this.client_s.close();
        }
        if (is_closed(this.client_s) && !is_closed(this.relay_s) && this.relay_s.bufferedAmount === 0 && this.c2r_schedule.length === 0) {
            log("Relay: closing.");
            this.relay_s.close();
        }

        if (this.r2c_schedule.length > 0 || this.client_s.bufferedAmount > 0
            || this.c2r_schedule.length > 0 || this.relay_s.bufferedAmount > 0)
            this.flush_timeout_id = setTimeout(this.flush.bind(this), this.rate_limit.when() * 1000);
    };
}

function BucketRateLimit(capacity, time) {
    this.amount = 0.0;
    /* capacity / time is the rate we are aiming for. */
    this.capacity = capacity;
    this.time = time;
    this.last_update = new Date();

    this.age = function() {
        var now;
        var delta;

        now = new Date();
        delta = (now - this.last_update) / 1000.0;
        this.last_update = now;

        this.amount -= delta * this.capacity / this.time;
        if (this.amount < 0.0)
            this.amount = 0.0;
    };

    this.update = function(n) {
        this.age();
        this.amount += n;

        return this.amount <= this.capacity;
    };

    /* How many seconds in the future will the limit expire? */
    this.when = function() {
        this.age();

        return (this.amount - this.capacity) / (this.capacity / this.time);
    }

    this.is_limited = function() {
        this.age();

        return this.amount > this.capacity;
    }
}

/* A rate limiter that never limits. */
function DummyRateLimit(capacity, time) {
    this.update = function(n) {
        return true;
    };

    this.when = function() {
        return 0.0;
    }

    this.is_limited = function() {
        return false;
    }
}

var HTML_ESCAPES = {
    "&": "amp",
    "<": "lt",
    ">": "gt",
    "'": "apos",
    "\"": "quot"
};
function escape_html(s) {
    return s.replace(/&<>'"/, function(x) { return HTML_ESCAPES[x] });
}

/* The usual embedded HTML badge. The "elem" member is a DOM element that can be
   included elsewhere. */
function Badge() {
    /* Number of proxy pairs currently connected. */
    this.num_proxy_pairs = 0;

    var table, tr, td, a, img;

    table = document.createElement("table");
    tr = document.createElement("tr");
    table.appendChild(tr);
    td = document.createElement("td");
    tr.appendChild(td);
    a = document.createElement("a");
    a.setAttribute("href", "options.html");
    a.setAttribute("target", "_blank");
    td.appendChild(a);
    img = document.createElement("img");
    img.setAttribute("src", "badge.png");
    img.setAttribute("alt", "Internet freedom");
    a.appendChild(img);

    this.elem = table;
    this.elem.className = "idle";

    this.proxy_begin = function() {
        this.num_proxy_pairs++;
        this.elem.className = "active";
    };

    this.proxy_end = function() {
        this.num_proxy_pairs--;
        if (this.num_proxy_pairs <= 0) {
            this.elem.className = "idle";
        }
    }

    this.disable = function() {
        this.elem.className = "disabled";
    }

    this.die = function() {
        this.elem.className = "dead";
    }
}

function quote(s) {
    return "\"" + s.replace(/([\\\"])/g, "\\$1") + "\"";
}

function maybe_quote(s) {
    if (!/^[a-zA-Z_]\w*$/.test(s))
        return quote(s);
    else
        return s;
}

function repr(x) {
    if (x === null) {
        return "null";
    } else if (typeof x === "undefined") {
        return "undefined";
    } else if (typeof x === "object") {
        var elems = [];
        for (var k in x)
            elems.push(maybe_quote(k) + ": " + repr(x[k]));
        return "{ " + elems.join(", ") + " }";
    } else if (typeof x === "string") {
        return quote(x);
    } else {
        return x.toString();
    }
}

/* Do we seem to be running in Tor Browser? Check the user-agent string and for
   no listing of supported MIME types. */
var TBB_UAS = [
    "Mozilla/5.0 (Windows NT 6.1; rv:10.0) Gecko/20100101 Firefox/10.0",
    "Mozilla/5.0 (Windows NT 6.1; rv:17.0) Gecko/20100101 Firefox/17.0",
];
function is_likely_tor_browser() {
    return TBB_UAS.indexOf(window.navigator.userAgent) > -1
        && (window.navigator.mimeTypes && window.navigator.mimeTypes.length === 0);
}

/* Are circumstances such that we should self-disable and not be a
   proxy? We take a best-effort guess as to whether this device runs on
   a battery or the data transfer might be expensive.

   http://www.zytrax.com/tech/web/mobile_ids.html
   http://googlewebmastercentral.blogspot.com/2011/03/mo-better-to-also-detect-mobile-user.html
   http://search.cpan.org/~cmanley/Mobile-UserAgent-1.05/lib/Mobile/UserAgent.pm
*/
function flashproxy_should_disable() {
    var ua;

    /* https://trac.torproject.org/projects/tor/ticket/6293 */
    if (is_likely_tor_browser()) {
         puts("Disable because running in Tor Browser.");
         return true;
    }

    ua = window.navigator.userAgent;
    if (ua !== null) {
        var UA_LIST = [
            /\bmobile\b/i,
            /\bandroid\b/i,
            /\bopera mobi\b/i,
        ];

        for (var i = 0; i < UA_LIST.length; i++) {
            var re = UA_LIST[i];

            if (ua.match(re)) {
                puts("Disable because User-Agent matches mobile pattern " + re + ".");
                return true;
            }
        }
    }

    if (ua.match(/\bsafari\b/i) && !ua.match(/\bchrome\b/i)
        && !ua.match(/\bversion\/[6789]\./i)) {
        /* Disable before Safari 6.0 because it doesn't have the hybi/RFC type
           of WebSockets. */
        puts("Disable because User-Agent is Safari before 6.0.");
        return true;
    }

    if (!WebSocket) {
        /* No WebSocket support. */
        puts("Disable because of no WebSocket support.");
        return true;
    }

    var flashproxy_allow = get_param_boolean(cookies, OPT_IN_COOKIE);
    var cookierequired = get_param_boolean(query, "cookierequired", false);
    /* flashproxy_allow may be true, false, or undefined. If undefined, only
       disable if the cookierequired param is also set. */
    if (flashproxy_allow === false) {
        puts("Disable because of cookie opt-out.");
        return true;
    } else if (cookierequired && !flashproxy_allow) {
        puts("Disable because of cookie required and no opt-in.");
        return true;
    }

    return false;
}

function flashproxy_badge_insert() {
    var fp;
    var e;

    fp = new FlashProxy();
    if (flashproxy_should_disable())
        fp.disable();

    /* http://intertwingly.net/blog/2006/11/10/Thats-Not-Write for this trick to
       insert right after the <script> element in the DOM. */
    e = document.body;
    while (e.lastChild && e.lastChild.nodeType === 1) {
        e = e.lastChild;
    }
    e.parentNode.appendChild(fp.badge_elem);

    return fp;
}
