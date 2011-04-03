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
	read_buf: java.nio.ByteBuffer.allocate(1024),
	accept_pending: [],
	connect_pending: [],
	read_pending: [],
	write_pending: [],

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

	/* Register/unregister descriptors and operations with the selector.
	   These assume that only one ops of each type is registered per
	   descriptor; for example, you can't register two read events, because
	   when one is unregistered it will unregister the other. */
	register: function(sd, ops) {
		var key = sd.keyFor(this.selector);
		var current_ops = 0;
		if (key)
			current_ops = key.interestOps();
		return sd.register(this.selector, current_ops | ops);
	},
	unregister: function(sd, ops) {
		var key = sd.keyFor(this.selector);
		var current_ops = 0;
		if (key)
			current_ops = key.interestOps();
		return sd.register(this.selector, current_ops & ~ops);
	},

	bytebuffer_to_string: function(bb) {
		return String(new java.lang.String(java.util.Arrays.copyOf(bb.array(), bb.position()), "ISO-8859-1"));
	},
	string_to_bytebuffer: function(s) {
		return java.nio.ByteBuffer.wrap(new java.lang.String(s).getBytes("ISO-8859-1"));
	},

	/* Stringify/serialize a socket descriptor. */
	s_sd: function(sd) {
		var s = sd.socket();
		return s["class"] + "\0" + s.getInetAddress().getHostAddress() + "\0" + s.getPort();
	},

	wait_for_event: function() {
		var n;
		do {
			n = this.selector.select();
		} while (n == 0);
		var key = this.selector.selectedKeys().iterator().next();
		var channel = key.channel();
		this.selector.selectedKeys().remove(key);
		var ev = {};
		if ((key.readyOps() & java.nio.channels.SelectionKey.OP_ACCEPT)
			== java.nio.channels.SelectionKey.OP_ACCEPT) {
			ev.type = "accept";
			ev.sd = channel.socket().accept().channel;
			/* Keep the pending record. */
			pending = this.get_pending(this.accept_pending, channel, true);
			ev.address = ev.sd.socket().getInetAddress().getHostAddress();
			ev.port = ev.sd.socket().getPort();
			ev.userdata = pending.userdata;
		} else if ((key.readyOps() & java.nio.channels.SelectionKey.OP_CONNECT)
			== java.nio.channels.SelectionKey.OP_CONNECT) {
			if (channel.isConnectionPending())
				channel.finishConnect();
			ev.type = "connect";
			ev.sd = channel;
			pending = this.get_pending(this.connect_pending, channel);
			ev.userdata = pending.userdata;
			this.unregister(channel, java.nio.channels.SelectionKey.OP_CONNECT);
		} else if ((key.readyOps() & java.nio.channels.SelectionKey.OP_READ)
			== java.nio.channels.SelectionKey.OP_READ) {
			ev.sd = channel;
			pending = this.get_pending(this.read_pending, channel);
			this.read_buf.clear();
			var n = channel.read(this.read_buf);
			if (n == -1) {
				ev.type = "eof";
			} else {
				ev.type = "recv";
				ev.userdata = pending.userdata;
				ev.data = this.bytebuffer_to_string(this.read_buf);
			}
			this.unregister(channel, java.nio.channels.SelectionKey.OP_READ);
		} else if ((key.readyOps() & java.nio.channels.SelectionKey.OP_WRITE)
			== java.nio.channels.SelectionKey.OP_WRITE) {
			ev.type = "send";
			ev.sd = channel;
			pending = this.get_pending(this.write_pending, channel);
			ev.userdata = pending.userdata;
			this.unregister(channel, java.nio.channels.SelectionKey.OP_WRITE);
		} else {
			io.print("Unknown selection key op.");
			io.quit();
		}
		return ev;
	},
	listen: function(address, port, userdata) {
		var sd = java.nio.channels.ServerSocketChannel.open();
		sd.configureBlocking(false);
		sd.socket().bind(java.net.InetSocketAddress(port));
		this.register(sd, java.nio.channels.SelectionKey.OP_ACCEPT);
		this.accept_pending.push({ sd: sd, userdata: userdata });
		return sd;
	},
	connect: function(address, port, userdata) {
		var sd = java.nio.channels.SocketChannel.open();
		sd.configureBlocking(false);
		this.register(sd, java.nio.channels.SelectionKey.OP_CONNECT);
		sd.connect(java.net.InetSocketAddress(address, port));
		this.connect_pending.push({ sd: sd, userdata: userdata });
		return sd;
	},
	recv: function(sd, userdata) {
		sd.configureBlocking(false);
		this.register(sd, java.nio.channels.SelectionKey.OP_READ);
		this.read_pending.push({ sd: sd, userdata: userdata });
		return sd;
	},
	send: function(sd, data, userdata) {
		sd.configureBlocking(false);
		this.register(sd, java.nio.channels.SelectionKey.OP_WRITE);
		sd.write(this.string_to_bytebuffer(data));
		this.write_pending.push({ sd: sd, data: data, userdata: userdata });
		return sd;
	},
	close: function(sd, userdata) {
		while (this.get_pending(this.accept_pending, sd))
			;
		while (this.get_pending(this.connect_pending, sd))
			;
		while (this.get_pending(this.read_pending, sd))
			;
		while (this.get_pending(this.write_pending, sd))
			;
		sd.close();
		sd.keyFor(this.selector).cancel();
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
		io.print("Connection from " + ev.address + ":" + ev.port + ".");
		connector.connect(DIRECTORY_ADDRESS, DIRECTORY_PORT, ev.sd);
		break;
	case "connect":
		peers[connector.s_sd(ev.sd)] = ev.userdata;
		peers[connector.s_sd(ev.userdata)] = ev.sd;
		/* Queue initial read events. */
		connector.recv(ev.sd, ev.userdata);
		connector.recv(ev.userdata, ev.sd);
		break;
	case "recv":
		connector.send(ev.userdata, ev.data);
		connector.recv(ev.sd, ev.userdata);
		break;
	case "eof":
		connector.close(ev.sd);
		var peer = peers[connector.s_sd(ev.sd)];
		if (peer) {
			connector.close(peer);
			delete peers[connector.s_sd(ev.sd)];
			delete peers[connector.s_sd(peer)];
		}
		break;
	case "error":
		io.quit();
		break;
	}
}
