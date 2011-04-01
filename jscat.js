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
	accept_pending: [],
	connect_pending: [],

	get_pending: function(pending_list, sd, keep) {
		for (var i = 0; i < pending_list.length; i++) {
			if (pending_list[i].sd == sd) {
				var pending = pending_list[i];
				if (!keep)
					pending_list.splice(i, 1)[0];
				return pending;
			}
		}
	},

	wait_for_event: function() {
		var n;
		do {
			n = this.selector.select();
		} while (n == 0);
		var key = this.selector.selectedKeys().iterator().next();
		this.selector.selectedKeys().remove(key);
		var ev = {};
		if ((key.readyOps() & java.nio.channels.SelectionKey.OP_ACCEPT)
			== java.nio.channels.SelectionKey.OP_ACCEPT) {
			ev.type = "accept";
			ev.sd = key.channel().socket().accept();
			/* Keep the pending record. */
			pending = this.get_pending(this.accept_pending, key.channel(), true);
			ev.userdata = pending.userdata;
		} else if ((key.readyOps() & java.nio.channels.SelectionKey.OP_CONNECT)
			== java.nio.channels.SelectionKey.OP_CONNECT) {
			if (key.channel().isConnectionPending())
				key.channel().finishConnect();
			ev.type = "connect";
			ev.sd = key.channel().socket();
			pending = this.get_pending(this.connect_pending, key.channel());
			ev.userdata = pending.userdata;
			key.cancel();
		} else {
			io.print("Unknown selection key op.");
			io.quit();
		}
		return ev;
	},
	listen: function(address, port, userdata) {
		var ssc = java.nio.channels.ServerSocketChannel.open();
		ssc.configureBlocking(false);
		var s = ssc.socket();
		s.bind(java.net.InetSocketAddress(port));
		ssc.register(this.selector, java.nio.channels.SelectionKey.OP_ACCEPT);
		this.accept_pending.push({ sd: ssc, userdata: userdata });
		return s;
	},
	connect: function(address, port, userdata) {
		var sc = java.nio.channels.SocketChannel.open();
		sc.configureBlocking(false);
		var s = sc.socket();
		sc.register(this.selector, java.nio.channels.SelectionKey.OP_CONNECT);
		sc.connect(java.net.InetSocketAddress(address, port));
		this.connect_pending.push({ sd: sc, userdata: userdata });
		return s;
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

while (true) {
	var ev = connector.wait_for_event();
	io.print("ev: " + repr(ev));
	switch (ev.type) {
	case "accept":
		io.print("Connection from "
			+ ev.sd.getInetAddress().getHostAddress() + ":"
			+ ev.sd.getPort() + ".");
		connector.connect(DIRECTORY_ADDRESS, DIRECTORY_PORT, ev.sd);
		break;
	case "connect":
		peers[ev.sd] = ev.userdata;
		peers[ev.userdata] = ev.sd;
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
