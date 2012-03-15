/* Query string parameters. These change how the program runs from the outside.
 * For example:
 *   http://www.example.com/embed.html?facilitator=127.0.0.1:9002&debug=1
 *
 * facilitator=<HOST>:<PORT>
 * The address of the facilitator to use. By default it is
 * DEFAULT_FACILITATOR_ADDR. Both <HOST> and <PORT> must be present.
 */

var DEFAULT_FACILITATOR_ADDR = {
    host: "tor-facilitator.bamsoftware.com",
    port: 9002
};

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

function FlashProxy()
{
    this.debug_div = document.createElement("div");
    this.debug_div.className = "debug";

    this.badge_elem = this.debug_div;
    this.badge_elem.setAttribute("id", "flashproxy-badge");

    this.puts = function(s) {
        if (this.debug_div) {
            this.debug_div.appendChild(document.createTextNode(s));
            this.debug_div.appendChild(document.createElement("br"));
        }
    };

    this.start = function() {
        var query;
        var fac_addr;

        query = parse_query_string(window.location.search.substr(1));

        fac_addr = get_query_param_addr(query, "facilitator", DEFAULT_FACILITATOR_ADDR);
        if (!fac_addr) {
            this.puts("Error: Facilitator spec must be in the form \"host:port\".");
            return;
        }

        this.proxy_main(fac_addr);
    };

    this.proxy_main = function(fac_addr) {
        var fac_url;
        var xhr;

        this.puts("Using facilitator " + format_addr(fac_addr) + ".");

        fac_url = "http://" + encodeURIComponent(fac_addr.host)
            + ":" + encodeURIComponent(fac_addr.port) + "/";
        xhr = new XMLHttpRequest();
        try {
            xhr.open("GET", fac_url);
        } catch (err) {
            /* An exception happens here when, for example, NoScript allows the
               domain on which the proxy badge runs, but not the domain to which
               it's trying to make the HTTP request. The exception message is
               like "Component returned failure code: 0x805e0006
               [nsIXMLHttpRequest.open]" on Firefox. */
            this.puts("Facilitator: exception while connecting: " + repr(err.message) + ".");
            return;
        }
        xhr.responseType = "text";
        xhr.onreadystatechange = function() {
            /* Status 0 is UNSENT. 4 is DONE. */
            if (xhr.status == 0 && xhr.statusText == null) {
                this.puts("Facilitator: cross-domain error.");
            } else if (xhr.readyState == 4) {
                if (xhr.status == 200)
                    this.fac_complete(xhr.responseText);
                else
                    this.puts("Facilitator: can't connect: got response code " + xhr.status + ".");
            }
        }.bind(this);
        this.puts("Facilitator: connecting to " + fac_url + ".");
        xhr.send(null);
    };

    this.fac_complete = function(text) {
        this.puts("Facilitator: got response \"" + text + "\".");
    };
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
