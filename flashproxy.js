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
 */

var DEFAULT_FACILITATOR_ADDR = {
    host: "tor-facilitator.bamsoftware.com",
    port: 9002
};

var DEFAULT_MAX_NUM_PROXY_PAIRS = 10;

var DEFAULT_FACILITATOR_POLL_INTERVAL = 10.0;
var MIN_FACILITATOR_POLL_INTERVAL = 1.0;

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

function make_websocket(addr)
{
    var url;

    url = "ws://" + encodeURIComponent(addr.host)
            + ":" + encodeURIComponent(addr.port) + "/";

    return (window.WebSocket || window.MozWebSocket)(url, "base64");
}

function FlashProxy()
{
    var debug_div;

    this.query = parse_query_string(window.location.search.substr(1));

    if (this.query.debug) {
        debug_div = document.createElement("pre");
        debug_div.className = "debug";

        this.badge_elem = debug_div;
    } else {
        var img;

        debug_div = undefined;
        img = document.createElement("img");
        img.setAttribute("src", "https://crypto.stanford.edu/flashproxy/badge.png");
        img.setAttribute("border", 0);

        this.badge_elem = img;
    }
    this.badge_elem.setAttribute("id", "flashproxy-badge");

    function puts(s) {
        if (debug_div) {
            var at_bottom;

            /* http://www.w3.org/TR/cssom-view/#element-scrolling-members */
            at_bottom = (debug_div.scrollTop + debug_div.clientHeight == debug_div.scrollHeight);
            debug_div.appendChild(document.createTextNode(s + "\n"));
            if (at_bottom)
                debug_div.scrollTop = debug_div.scrollHeight;
        }
    };

    var rate_limit = {
        is_limited: function() { return false; },
        when: function() { return 0; }
    };

    this.proxy_pairs = [];

    this.start = function() {
        var client_addr;
        var relay_addr;

        this.fac_addr = get_query_param_addr(this.query, "facilitator", DEFAULT_FACILITATOR_ADDR);
        if (!this.fac_addr) {
            puts("Error: Facilitator spec must be in the form \"host:port\".");
            return;
        }

        this.max_num_proxy_pairs = get_query_param_integer(this.query, "max_clients", DEFAULT_MAX_NUM_PROXY_PAIRS);
        if (this.max_num_proxy_pairs == null || this.max_num_proxy_pairs < 0) {
            puts("Error: max_clients must be a nonnegative integer.");
            return;
        }

        this.facilitator_poll_interval = get_query_param_timespec(this.query, "facilitator_poll_interval", DEFAULT_FACILITATOR_POLL_INTERVAL);
        if (this.facilitator_poll_interval == null || this.facilitator_poll_interval < MIN_FACILITATOR_POLL_INTERVAL) {
            puts("Error: facilitator_poll_interval must be a nonnegative number at least " + MIN_FACILITATOR_POLL_INTERVAL + ".");
            return;
        }

        client_addr = get_query_param_addr(this.query, "client");
        relay_addr = get_query_param_addr(this.query, "relay");
        if (client_addr !== undefined && relay_addr !== undefined) {
            this.make_proxy_pair(client_addr, relay_addr);
        } else if (client_addr !== undefined) {
            puts("Error: the \"client\" parameter requires \"relay\" also.")
            return;
        } else if (relay_addr !== undefined) {
            puts("Error: the \"relay\" parameter requires \"client\" also.")
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
        }
        if (!response.relay) {
            puts("Error: missing relay in response.");
            return;
        }
        relay_addr = parse_addr_spec(response.relay);
        if (relay_addr === null) {
            puts("Error: can't parse relay spec " + repr(response.relay) + ".");
        }
        puts("Facilitator: got client:" + repr(client_spec) + " "
            + "relay:" + repr(relay_spec) + ".");

        this.make_proxy_pair(client_addr, relay_addr);
    };

    this.make_proxy_pair = function(client_addr, relay_addr) {
        var proxy_pair;

        puts("make_proxy_pair");

        proxy_pair = new ProxyPair(client_addr, relay_addr);
        this.proxy_pairs.push(proxy_pair);
        proxy_pair.complete_callback = function(event) {
            puts("Complete.");
            /* Delete from the list of active proxy pairs. */
            this.proxy_pairs.splice(this.proxy_pairs.indexOf(proxy_pair), 1);
        }.bind(this);
        proxy_pair.connect();
    };

    /* An instance of a client-relay connection. */
    function ProxyPair(client_addr, relay_addr)
    {
        function log(s)
        {
            puts(s)
        }

        this.client_addr = client_addr;
        this.relay_addr = relay_addr;

        this.c2r_schedule = [];
        this.r2c_schedule = [];

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

            if (is_closed(this.client_s) && is_closed(this.relay_s))
                this.complete_callback();
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

        /* Send as much data as the rate limit currently allows. */
        this.flush = function() {
            var busy;

            if (this.flush_timeout_id)
                clearTimeout(this.flush_timeout_id);
            this.flush_timeout_id = null;

            busy = true;
            while (busy && !rate_limit.is_limited()) {
                busy = false;
                if (is_open(this.client_s) && this.r2c_schedule.length > 0) {
                    this.client_s.send(this.r2c_schedule.shift());
                    busy = true;
                }
                if (is_open(this.relay_s) && this.c2r_schedule.length > 0) {
                    this.relay_s.send(this.c2r_schedule.shift());
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
                this.flush_timeout_id = setTimeout(this.flush, rate_limit.when() * 1000);
        };
    }
}

/* This is the non-functional badge that occupies space when
   flashproxy_should_disable decides that the proxy shouldn't run. */
function DummyFlashProxy()
{
    var img;

    img = document.createElement("img");
    img.setAttribute("src", "https://crypto.stanford.edu/flashproxy/badge.png");
    img.setAttribute("border", 0);
    img.setAttribute("id", "flashproxy-badge");

    this.badge_elem = img;

    this.start = function() {
    };
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
    var e;

    if (flashproxy_should_disable()) {
        fp = new DummyFlashProxy();
    } else {
        fp = new FlashProxy();
    }

    /* http://intertwingly.net/blog/2006/11/10/Thats-Not-Write for this trick to
       insert right after the <script> element in the DOM. */
    e = document;
    while (e.lastChild && e.lastChild.nodeType == 1) {
        e = e.lastChild;
    }
    e.parentNode.appendChild(fp.badge_elem);

    return fp;
}
