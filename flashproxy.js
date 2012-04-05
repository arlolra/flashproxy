/* Query string parameters. These change how the program runs from the outside.
 * For example:
 *   http://www.example.com/embed.html?facilitator=127.0.0.1:9002&debug=1
 *
 * client=<HOST>:<PORT>
 * The address of the client to connect to. The proxy normally receives this
 * information from the facilitator. When this option is used, the facilitator
 * query is not done. The "relay" parameter must be given as well.
 *
 * debug=1
 * If set (to any value), show verbose terminal-like output instead of the
 * badge.
 *
 * facilitator=<HOST>:<PORT>
 * The address of the facilitator to use. By default it is
 * DEFAULT_FACILITATOR_ADDR. Both <HOST> and <PORT> must be present.
 *
 * facilitator_poll_interval=<FLOAT>
 * How often to poll the facilitator, in seconds. The default is
 * DEFAULT_FACILITATOR_POLL_INTERVAL. There is a sanity-check minimum of 1.0 s.
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

var FLASHPROXY_INFO_URL = "https://crypto.stanford.edu/flashproxy/";

var DEFAULT_FACILITATOR_ADDR = {
    host: "tor-facilitator.bamsoftware.com",
    port: 9002
};

var DEFAULT_MAX_NUM_PROXY_PAIRS = 10;

var DEFAULT_FACILITATOR_POLL_INTERVAL = 10.0;
var MIN_FACILITATOR_POLL_INTERVAL = 1.0;

/* Bytes per second. Set to undefined to disable limit. */
var DEFAULT_RATE_LIMIT = undefined;
var MIN_RATE_LIMIT = 10 * 1024;
var RATE_LIMIT_HISTORY = 5.0;

/* Gecko browsers use the name MozWebSocket. Also we can test whether WebSocket
   is defined to see if WebSockets are supported at all. */
var WebSocket = window.WebSocket || window.MozWebSocket;

var query = parse_query_string(window.location.search.substr(1));
var debug_div;

if (query.debug) {
    debug_div = document.createElement("pre");
    debug_div.className = "debug";
}

function puts(s)
{
    if (debug_div) {
        var at_bottom;

        /* http://www.w3.org/TR/cssom-view/#element-scrolling-members */
        at_bottom = (debug_div.scrollTop + debug_div.clientHeight == debug_div.scrollHeight);
        debug_div.appendChild(document.createTextNode(s + "\n"));
        if (at_bottom)
            debug_div.scrollTop = debug_div.scrollHeight;
    }
}

/* Parse a URL query string or application/x-www-form-urlencoded body. The
   return type is an object mapping string keys to string values. By design,
   this function doesn't support multiple values for the same named parameter,
   for example "a=1&a=2&a=3"; the first definition always wins. Returns null on
   error.

   Always decodes from UTF-8, not any other encoding.

   http://dev.w3.org/html5/spec/Overview.html#url-encoded-form-data */
function parse_query_string(qs)
{
    var strings;
    var result;

    result = {};
    if (qs)
        strings = qs.split("&");
    else
        strings = {}
    for (var i = 0; i < strings.length; i++) {
        var string = strings[i];
        var j, name, value;

        j = string.indexOf("=");
        if (j == -1) {
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

/* Get a query string parameter and parse it as an address spec. Returns
   default_val if param is not defined in the query string. Returns null on a
   parsing error. */
function get_query_param_addr(query, param, default_val)
{
    var val;

    val = query[param];
    if (val === undefined)
        return default_val;
    else
        return parse_addr_spec(val);
}

/* Get an integer from the given movie parameter, or the given default. Returns
   null on error. */
function get_query_param_integer(query, param, default_val)
{
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

/* Get a number from the given movie parameter, or the given default. Returns
   null on error. */
function get_query_param_number(query, param, default_val)
{
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
function get_query_param_timespec(query, param, default_val)
{
    return get_query_param_number(query, param, default_val);
}

/* Parse a count of bytes. A suffix of "k", "m", or "g" (or uppercase)
   does what you would think. Returns null on error. */
function parse_byte_count(spec)
{
    var UNITS = {
        k: 1024, m: 1024 * 1024, g: 1024 * 1024 * 1024,
        K: 1024, M: 1024 * 1024, G: 1024 * 1024 * 1024
    };
    var count, units;
    var matches;

    matches = spec.match(/^(\d+(?:\.\d*)?)(\w*)$/);
    if (matches == null)
        return null;

    count = Number(matches[1]);
    if (isNaN(count))
        return null;

    if (matches[2] == "") {
        units = 1;
    } else {
        units = UNITS[matches[2]];
        if (units == null)
            return null;
    }

    return count * Number(units);
}

/* Get a count of bytes from a string specification like "100" or "1.3m".
   Returns null on error. */
function get_query_param_byte_count(query, param, default_val)
{
    var spec;

    spec = query[param];
    if (spec === undefined)
        return default_val;
    else
        return parse_byte_count(spec);
}

/* Parse an address in the form "host:port". Returns an Object with
   keys "host" (String) and "port" (int). Returns null on error. */
function parse_addr_spec(spec)
{
    var groups;
    var host, port;

    groups = spec.match(/^([^:]+):(\d+)$/);
    if (!groups)
        return null;
    host = groups[1];
    port = parseInt(groups[2], 10);
    if (isNaN(port) || port < 0 || port > 65535)
        return null;

    return { host: host, port: port }
}

function format_addr(addr)
{
    return addr.host + ":" + addr.port;
}

/* Does the WebSocket implementation in this browser support binary frames? (RFC
   6455 section 5.6.) If not, we have to use base64-encoded text frames. It is
   assumed that the client and relay endpoints always support binary frames. */
function have_websocket_binary_frames()
{
    return false;
}

function make_websocket(addr)
{
    var url;
    var ws;

    url = "ws://" + encodeURIComponent(addr.host)
            + ":" + encodeURIComponent(addr.port) + "/";

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

function FlashProxy()
{
    this.badge = new Badge();
    if (query.debug)
        this.badge_elem = debug_div;
    else
        this.badge_elem = this.badge.elem;
    this.badge_elem.setAttribute("id", "flashproxy-badge");

    this.proxy_pairs = [];

    this.start = function() {
        var client_addr;
        var relay_addr;
        var rate_limit_bytes;

        this.fac_addr = get_query_param_addr(query, "facilitator", DEFAULT_FACILITATOR_ADDR);
        if (!this.fac_addr) {
            puts("Error: Facilitator spec must be in the form \"host:port\".");
            this.die();
            return;
        }

        this.max_num_proxy_pairs = get_query_param_integer(query, "max_clients", DEFAULT_MAX_NUM_PROXY_PAIRS);
        if (this.max_num_proxy_pairs == null || this.max_num_proxy_pairs < 0) {
            puts("Error: max_clients must be a nonnegative integer.");
            this.die();
            return;
        }

        this.facilitator_poll_interval = get_query_param_timespec(query, "facilitator_poll_interval", DEFAULT_FACILITATOR_POLL_INTERVAL);
        if (this.facilitator_poll_interval == null || this.facilitator_poll_interval < MIN_FACILITATOR_POLL_INTERVAL) {
            puts("Error: facilitator_poll_interval must be a nonnegative number at least " + MIN_FACILITATOR_POLL_INTERVAL + ".");
            this.die();
            return;
        }

        if (query["ratelimit"] == "off")
            rate_limit_bytes = undefined;
        else
            rate_limit_bytes = get_query_param_byte_count(query, "ratelimit", DEFAULT_RATE_LIMIT);
        if (rate_limit_bytes === undefined) {
            this.rate_limit = new DummyRateLimit();
        } else if (rate_limit_bytes == null || rate_limit_bytes < MIN_FACILITATOR_POLL_INTERVAL) {
            puts("Error: ratelimit must be a nonnegative number at least " + MIN_RATE_LIMIT + ".");
            this.die();
            return;
        } else {
            this.rate_limit = new BucketRateLimit(rate_limit_bytes * RATE_LIMIT_HISTORY, RATE_LIMIT_HISTORY);
        }

        client_addr = get_query_param_addr(query, "client");
        relay_addr = get_query_param_addr(query, "relay");
        if (client_addr !== undefined && relay_addr !== undefined) {
            this.make_proxy_pair(client_addr, relay_addr);
        } else if (client_addr !== undefined) {
            puts("Error: the \"client\" parameter requires \"relay\" also.")
            this.die();
            return;
        } else if (relay_addr !== undefined) {
            puts("Error: the \"relay\" parameter requires \"client\" also.")
            this.die();
            return;
        } else {
            this.proxy_main();
        }
    };

    this.proxy_main = function() {
        var fac_url;
        var xhr;

        if (this.proxy_pairs.length >= this.max_num_proxy_pairs) {
            setTimeout(this.proxy_main.bind(this), this.facilitator_poll_interval);
            return;
        }

        fac_url = "http://" + encodeURIComponent(this.fac_addr.host)
            + ":" + encodeURIComponent(this.fac_addr.port) + "/";
        xhr = new XMLHttpRequest();
        try {
            xhr.open("GET", fac_url);
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
            if (xhr.readyState == xhr.DONE) {
                if (xhr.status == 200)
                    this.fac_complete(xhr.responseText);
                else if (xhr.status == 0 && xhr.statusText == "")
                    puts("Facilitator: same-origin error.");
                else
                    puts("Facilitator: can't connect: got status " + repr(xhr.status) + " and status text " + repr(xhr.statusText) + ".");
            }
        }.bind(this);
        puts("Facilitator: connecting to " + fac_url + ".");
        xhr.send(null);
    };

    this.fac_complete = function(text) {
        var response;
        var client_addr;
        var relay_addr;

        setTimeout(this.proxy_main.bind(this), this.facilitator_poll_interval * 1000);

        response = parse_query_string(text);

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
            this.badge.proxy_end();
        }.bind(this);
        proxy_pair.connect();

        this.badge.proxy_begin();
    };

    /* Cease all network operations and prevent any future ones. */
    this.disable = function() {
        puts("disabling");
        this.proxy_main = function() { };
        this.make_proxy_pair = function(client_addr, relay_addr) { };
        while (this.proxy_pairs.length > 0)
            this.proxy_pairs.pop().close();
        this.badge.set_color("#777");
        this.badge.refresh();
    };

    this.die = function() {
        puts("die");
        this.badge.set_color("#111");
    };
}

/* An instance of a client-relay connection. */
function ProxyPair(client_addr, relay_addr, rate_limit)
{
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
        return ws.readyState == ws.OPEN;
    }

    function is_closed(ws)
    {
        return ws.readyState == ws.CLOSED;
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
            if (is_open(this.client_s) && this.r2c_schedule.length > 0) {
                chunk = this.r2c_schedule.shift();
                this.rate_limit.update(chunk.length);
                this.client_s.send(chunk);
                busy = true;
            }
            if (is_open(this.relay_s) && this.c2r_schedule.length > 0) {
                chunk = this.c2r_schedule.shift();
                this.rate_limit.update(chunk.length);
                this.relay_s.send(chunk);
                busy = true;
            }
        }

        if (is_closed(this.relay_s) && !is_closed(this.client_s) && this.r2c_schedule.length == 0) {
            log("Client: closing.");
            this.client_s.close();
        }
        if (is_closed(this.client_s) && !is_closed(this.relay_s) && this.c2r_schedule.length == 0) {
            log("Relay: closing.");
            this.relay_s.close();
        }

        if (this.r2c_schedule.length > 0 || this.c2r_schedule.length > 0)
            this.flush_timeout_id = setTimeout(this.flush.bind(this), this.rate_limit.when() * 1000);
    };
}

function BucketRateLimit(capacity, time)
{
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
function DummyRateLimit(capacity, time)
{
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
function escape_html(s)
{
    return s.replace(/&<>'"/, function(x) { return HTML_ESCAPES[x] });
}

/* The usual embedded HTML badge. The "elem" member is a DOM element that can be
   included elsewhere. */
function Badge()
{
    /* Number of proxy pairs currently connected. */
    this.num_proxy_pairs = 0;
    /* Number of proxy pairs ever connected. */
    this.total_proxy_pairs = 0;

    this.counter_text = document.createElement("p");

    var div, subdiv, a, img;

    div = document.createElement("div");

    a = document.createElement("a");
    a.setAttribute("href", FLASHPROXY_INFO_URL);

    img = document.createElement("img");
    img.setAttribute("src", "badge.png");

    subdiv = document.createElement("div");

    this.counter_text = document.createElement("p");

    div.appendChild(a);
    a.appendChild(img);
    div.appendChild(subdiv)
    subdiv.appendChild(this.counter_text);

    this.elem = div;

    this.proxy_begin = function() {
        this.num_proxy_pairs++;
        this.total_proxy_pairs++;
        this.refresh();
    };

    this.proxy_end = function() {
        this.num_proxy_pairs--;
        this.refresh();
    }

    this.refresh = function() {
        this.counter_text.innerHTML = escape_html(String(this.total_proxy_pairs));
    };

    this.set_color = function(color) {
        this.elem.style.backgroundColor = color;
    };

    this.refresh();
}

function quote(s)
{
    return "\"" + s.replace(/([\\\"])/, "\\$1") + "\"";
}

function maybe_quote(s)
{
    if (!/^[a-zA-Z_]\w*$/.test(s))
        return quote(s);
    else
        return s;
}

function repr(x)
{
    if (x === null) {
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

/* Are circumstances such that we should self-disable and not be a
   proxy? We take a best-effort guess as to whether this device runs on
   a battery or the data transfer might be expensive.

   http://www.zytrax.com/tech/web/mobile_ids.html
   http://googlewebmastercentral.blogspot.com/2011/03/mo-better-to-also-detect-mobile-user.html
   http://search.cpan.org/~cmanley/Mobile-UserAgent-1.05/lib/Mobile/UserAgent.pm
*/
function flashproxy_should_disable()
{
    var ua;

    ua = window.navigator.userAgent;
    if (ua != null) {
        var UA_LIST = [
            /\bmobile\b/i,
            /\bandroid\b/i,
            /\bopera mobi\b/i,
            /* Disable on Safari because it doesn't have the hybi/RFC type of
               WebSockets. */
            /\bsafari\b/i,
        ];

        for (var i = 0; i < UA_LIST.length; i++) {
            var re = UA_LIST[i];

            if (ua.match(re)) {
                return true;
            }
        }
    }

    return false;
}

function flashproxy_badge_insert()
{
    var fp;
    var e;

    fp = new FlashProxy();
    if (flashproxy_should_disable())
        fp.disable();

    /* http://intertwingly.net/blog/2006/11/10/Thats-Not-Write for this trick to
       insert right after the <script> element in the DOM. */
    e = document;
    while (e.lastChild && e.lastChild.nodeType == 1) {
        e = e.lastChild;
    }
    e.parentNode.appendChild(fp.badge_elem);

    return fp;
}
