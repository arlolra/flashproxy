#!/usr/bin/env node

var path = require("path");
var fs = require("fs");
var net = require("net");

// Get a querystring from the command line
var location_search = "debug=1&initial_facilitator_poll_interval=10";
if (process.argv[2] != null)
    location_search = process.argv[2];

// Setup environment variables for node.js
var XMLHttpRequest = require("xmlhttprequest").XMLHttpRequest;
var window = {
    location: { search: "?" + location_search },
    navigator: { userAgent: "Chrome/16" },
    WebSocket: require("ws")
};

// Include flashproxy.js using eval to avoid modifying it.
var file = path.join(__dirname, "flashproxy.js");
try {
    var data = fs.readFileSync(file, "utf8");
} catch (e) {
    console.log("Can't locate the flashproxy.js file. You probably need to run \"npm install\".");
    process.exit(1);
}
eval(data);


ProxyPair.prototype.client_onopen_callback = function(event) {
    var ws = event.target;
    puts(ws.label + ": connected.");

    puts("Relay: connecting.");
    this.relay_s = new TCP(this.relay_addr, "Relay", this);

    this.relay_s.addListener("connect", this.relay_s.onopen);
    this.relay_s.addListener("close", this.relay_s.onclose);
    this.relay_s.addListener("error", this.relay_s.onerror);
    this.relay_s.addListener("data", this.relay_s.onmessage);
};

function TCP(addr, label, pp) {
    this.socket = net.connect(addr);
    this.label = label;
    this.pp = pp;
}

TCP.prototype.onopen = function () {
    puts(this.label + ": connected.");
}

TCP.prototype.close = function () {
    this.socket.end();
}

function is_closed(ws) {
    return ws === undefined || ws.readyState === window.WebSocket.CLOSED;
}

TCP.prototype.onclose = function () {
    puts(this.label + ": closed.");
    this.pp.flush();
    if (this.pp.running && is_closed(this.pp.client_s) && is_closed(this)) {
        this.pp.running = false;
        this.pp.complete_callback();
    }
}

TCP.prototype.onerror = function () {
    puts(this.label + ": error.");
    this.pp.close();
}

TCP.prototype.onmessage = function (data) {
    this.pp.r2c_schedule.push(data);
    this.pp.flush();
}

TCP.prototype.addListener = function (event, cb) {
    this.socket.on(event, cb.bind(this));
};

TCP.prototype.send = function (data) {
    this.socket.write(data);
};

Object.defineProperty(TCP.prototype, 'bufferedAmount', {
    get: function get() {
        return this.socket ? this.socket.bufferSize : 0;
    }
});

Object.defineProperty(TCP.prototype, 'readyState', {
    get: function get() {
        if (!this.socket)
            return window.WebSocket.CLOSED;
        switch (this.socket.readyState) {
            case "opening":
                return window.WebSocket.CONNECTING;
            case "open":
                return window.WebSocket.OPEN;
            default:
                return window.WebSocket.CLOSED;
        }
    }
});


// Start 'er up
flashproxy_badge_new().start();
