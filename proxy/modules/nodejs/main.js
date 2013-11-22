#!/usr/bin/env node

var fs = require("fs");
var path = require("path");
var querystring = require("querystring")

var meta = require("./package.json")

// Get a querystring from the command line
var argv = require("optimist")
    .default("debug", 1)
    .default("initial_facilitator_poll_interval", 10)
    .argv

if ("v" in argv || "version" in argv) {
    console.log(meta.version)
    process.exit()
}
if ("h" in argv || "help" in argv) {
    console.log("Usage: %s [-h|-v] [--param[=val]] ... [extra querystring]\n\
\n\
Run flashproxy on the node.js server. You can give querystring parameters as \n\
command line options; see the main flashproxy.js program for documentation on \n\
which parameters are accepted. For example: \n\
\n\
%s --debug --initial_facilitator_poll_interval=10\n\
", argv.$0, argv.$0)
    process.exit()
}

var extra = argv._.join("&")
delete argv._
delete argv.$0
var location_search = querystring.stringify(argv)
if (extra) {
    location_search += "&" + extra
}

// Setup global variables that flashproxy.js expects
var XMLHttpRequest = require("xmlhttprequest").XMLHttpRequest;
var window = {
    location: { search: "?" + location_search },
    navigator: { userAgent: "Chrome/16" },
    WebSocket: require("ws")
};

// Include flashproxy.js using eval to run it in the scope of this script
// so we don't need to make non-browser adjustments to flashproxy.js
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
