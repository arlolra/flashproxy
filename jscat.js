load("util.js");

var io = {
	print: function(s) {
		return print(s);
	},
	quit: function() {
		return quit();
	},
};

var connector = {
	selector: java.nio.channels.Selector.open(),

	wait_for_event: function() {
		var n;
		do {
			n = this.selector.select();
		} while (n == 0);
		var key = this.selector.selectedKeys().iterator().next();
		var ev = {};
		if (key.readyOps() & java.nio.channels.SelectionKey.OP_ACCEPT) {
			ev.type = "accept";
			ev.sd = key.channel().socket().accept();
			ev.address = ev.sd.getInetAddress().getHostAddress();
			ev.port = ev.sd.getPort();
			/* userdata */
			return ev;
		}
	},
	listen: function(address, port, userdata) {
		var ssc = java.nio.channels.ServerSocketChannel.open();
		ssc.configureBlocking(false);
		var s = ssc.socket();
		s.bind(java.net.InetSocketAddress(port));
		ssc.register(this.selector, java.nio.channels.SelectionKey.OP_ACCEPT);
		/* userdata */
		return s;
	},
	connect: function(address, port, userdata) {
	},
	recv: function(sd, userdata) {
	},
	send: function(sd, data, userdata) {
	},
	close: function(sd, userdata) {
	},
};

io.print("jscat starting.")

var LOCAL_ADDRESS = "0.0.0.0";
var LOCAL_PORT = 9998;

var DIRECTORY_ADDRESS = "localhost";
var DIRECTORY_PORT = 9999;

var peers = {};

var l = connector.listen(LOCAL_ADDRESS, LOCAL_PORT);
print("Listening socket: " + l);

while (true) {
	var ev = connector.wait_for_event();
	print("ev: " + repr(ev));
	switch (ev.type) {
	case "accept":
		io.print("Connection from " + ev.address + ":" + ev.port + ".");
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
		var peer = peers[ev.sd];
		connector.close(peer[ev.sd]);
		delete peers[ev.sd];
		delete peers[peer];
		break;
	case "error":
		io.quit();
		break;
	}
}
