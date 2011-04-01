var io = {
	"print": function(s) {
		return print(s);
	},
	"quit": function() {
		return quit();
	},
};

var connector = {
	"wait_for_event": function() {
	},
	"listen": function(port, userdata) {
	},
	"connect": function(address, port, userdata) {
	},
	"recv": function(sd, userdata) {
	},
	"send": function(sd, data, userdata) {
	},
	"close": function(sd, userdata) {
	},
};

io.print("jscat starting.")

var LOCAL_PORT = 9998;

var DIRECTORY_ADDRESS = "localhost";
var DIRECTORY_PORT = 9999;

var peer = {};

connector.listen(LOCAL_PORT);

while (true) {
	var ev = connector.wait_for_event();
	switch (ev.type) {
	case "accept":
		connector.connect(DIRECTORY_ADDRESS, DIRECTORY_PORT, ev.sd);
		break;
	case "connect":
		peer[ev.sd] = ev.userdata;
		peer[ev.userdata] = ev.sd;
		/* Queue initial read events. */
		connector.recv(ev.sd, ev.userdata);
		connector.recv(ev.userdata, ev.sd);
		break;
	case "recv":
		connector.send(ev.userdata, ev.data);
		break;
	case "close":
		connector.close(peer[ev.sd]);
		peer[ev.sd] = peer[peer[ev.sd]] = undefined;
		break;
	case "error":
		io.quit();
		break;
	}
}
