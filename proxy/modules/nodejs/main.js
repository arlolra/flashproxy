#!/usr/bin/env node

var path = require("path");
var fs = require("fs");

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

// Start 'er up
flashproxy_badge_new().start();
