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
	events: [],

	/* Register/unregister descriptors and operations with the selector.
	   These assume that only one ops of each type is registered per
	   descriptor; for example, you can't register two read events, because
	   when one is unregistered it will unregister the other. */
	register: function(sd, ops) {
		var key = sd.keyFor(this.selector);
		var current_ops = 0;
		if (key)
			current_ops = key.interestOps();
		sd.register(this.selector, current_ops | ops);
	},
	unregister: function(sd, ops) {
		var key = sd.keyFor(this.selector);
		if (key && key.isValid())
			sd.register(this.selector, key.interestOps() & ~ops);
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

	handle_selection_key: function(key) {
		var channel = key.channel();
		if ((key.readyOps() & java.nio.channels.SelectionKey.OP_ACCEPT)
			== java.nio.channels.SelectionKey.OP_ACCEPT) {
			this.op_accept(channel);
			/* For accept only, do not unregister the selection key. */
		} else if ((key.readyOps() & java.nio.channels.SelectionKey.OP_CONNECT)
			== java.nio.channels.SelectionKey.OP_CONNECT) {
			this.op_connect(channel);
			this.unregister(channel, java.nio.channels.SelectionKey.OP_CONNECT);
		} else if ((key.readyOps() & java.nio.channels.SelectionKey.OP_READ)
			== java.nio.channels.SelectionKey.OP_READ) {
			this.op_read(channel);
			this.unregister(channel, java.nio.channels.SelectionKey.OP_READ);
		} else if ((key.readyOps() & java.nio.channels.SelectionKey.OP_WRITE)
			== java.nio.channels.SelectionKey.OP_WRITE) {
			this.op_write(channel);
			this.unregister(channel, java.nio.channels.SelectionKey.OP_WRITE);
		} else {
			throw new Error("Unknown selection key op.");
		}
	},
	op_accept: function(channel) {
		var c = channel.socket().accept();
		this.events.push({
			type: "accept",
			sd: channel,
			address: c.getInetAddress().getHostAddress(),
			port: c.getPort(),
			client: c.channel,
		});
	},
	op_connect: function(channel) {
		if (channel.isConnectionPending())
			channel.finishConnect();
		this.events.push({
			type: "connect",
			sd: channel,
			address: channel.socket().getInetAddress().getHostAddress(),
			port: channel.socket().getPort(),
		});
	},
	op_read: function(channel) {
		this.read_buf.clear();
		var n = channel.read(this.read_buf);
		var data;
		if (n == -1)
			data = undefined;
		else
			data = this.bytebuffer_to_string(this.read_buf);
		this.events.push({
			type: "recv",
			sd: channel,
			data: data,
		});
	},
	op_write: function(channel) {
		this.events.push({
			type: "send",
			sd: channel,
		});
	},

	wait_for_event: function() {
		while (true) {
			if (this.events.length > 0)
				return this.events.shift();

			var n;
			do {
				n = this.selector.select();
			} while (n == 0);

			var iter = this.selector.selectedKeys().iterator();
			while (iter.hasNext())
				this.handle_selection_key(iter.next());
			this.selector.selectedKeys().clear();
		}
	},
	listen: function(address, port) {
		var sd = java.nio.channels.ServerSocketChannel.open();
		sd.configureBlocking(false);
		sd.socket().bind(java.net.InetSocketAddress(port));
		this.register(sd, java.nio.channels.SelectionKey.OP_ACCEPT);
		return sd;
	},
	connect: function(address, port) {
		var sd = java.nio.channels.SocketChannel.open();
		sd.configureBlocking(false);
		this.register(sd, java.nio.channels.SelectionKey.OP_CONNECT);
		sd.connect(java.net.InetSocketAddress(address, port));
		return sd;
	},
	recv: function(sd) {
		sd.configureBlocking(false);
		this.register(sd, java.nio.channels.SelectionKey.OP_READ);
		return sd;
	},
	send: function(sd, data) {
		sd.configureBlocking(false);
		this.register(sd, java.nio.channels.SelectionKey.OP_WRITE);
		sd.write(this.string_to_bytebuffer(data));
		return sd;
	},
	close: function(sd) {
		sd.close();
	},
};


accept_pending = [];
connect_pending = [];
recv_pending = [];
send_pending = [];

function add_pending(pending_list, id, data) {
	pending_list.push({ id: id, data: data });
}

function get_pending(pending_list, id, keep) {
	for (var i = 0; i < pending_list.length; i++) {
		if (pending_list[i].id == id) {
			var pending = pending_list[i];
			if (!keep)
				pending_list.splice(i, 1)[0];
			return pending.data;
		}
	}
}

function listen(address, port, callback, userdata) {
	var sd = connector.listen(address, port);
	add_pending(accept_pending, sd, { callback: callback, userdata: userdata });
	return sd;
}

function connect(address, port, callback, userdata) {
	var sd = connector.connect(address, port);
	add_pending(connect_pending, sd, { callback: callback, userdata: userdata });
	return sd;
}

function recv(sd, callback, userdata) {
	var sd = connector.recv(sd);
	add_pending(recv_pending, sd, { callback: callback, userdata: userdata });
	return sd;
}

function send(sd, data, callback, userdata) {
	var sd = connector.send(sd, data);
	add_pending(send_pending, sd, { callback: callback, userdata: userdata });
	return sd;
}

function close(sd) {
	while (get_pending(accept_pending, sd))
		;
	while (get_pending(connect_pending, sd))
		;
	while (get_pending(recv_pending, sd))
		;
	while (get_pending(send_pending, sd))
		;
	connector.close(sd);
};

function event_loop() {
	while (true) {
		var ev = connector.wait_for_event();
		io.print("ev: " + repr(ev));

		var pending, args;
		switch (ev.type) {
		case "accept":
			/* accept events are persistent; don't remove pending
			   except on error. */
			pending = this.get_pending(this.accept_pending, ev.sd, true);
			args = [ev.client, ev.address, ev.port];
			break;
		case "connect":
			pending = this.get_pending(this.connect_pending, ev.sd);
			args = [ev.address, ev.port];
			break;
		case "recv":
			pending = this.get_pending(this.recv_pending, ev.sd);
			args = [ev.data];
			break;
		case "send":
			pending = this.get_pending(this.send_pending, ev.sd);
			args = [];
			break;
		default:
			throw new Error("Unknown event type \"" + ev.type + "\".");
		}
		/* Add standard arguments. */
		args = [ev.sd, pending.userdata].concat(args);
		if (pending.callback)
			pending.callback.apply(null, args);
	}
}


io.print("jscat starting.")

var LOCAL_ADDRESS = "0.0.0.0";
var LOCAL_PORT = 9998;

var DIRECTORY_ADDRESS = "localhost";
var DIRECTORY_PORT = 9999;

var peers = {};

function accept_handler(sd, userdata, client, address, port) {
	io.print("Connection from " + address + ":" + port + ".");
	/* Pass the client as userdata. */
	connect(DIRECTORY_ADDRESS, DIRECTORY_PORT, connect_handler, client);
}

function connect_handler(sd, userdata, address, port) {
	io.print("Connection to " + address + ":" + port + ".");
	peers[connector.s_sd(sd)] = userdata;
	peers[connector.s_sd(userdata)] = sd;
	/* Queue initial read events. */
	recv(sd, recv_handler, userdata);
	recv(userdata, recv_handler, sd);
}

function recv_handler(sd, userdata, data) {
	if (data == undefined) {
		close(sd);
		var peer = peers[connector.s_sd(sd)];
		if (peer) {
			connector.close(peer);
			delete peers[connector.s_sd(sd)];
			delete peers[connector.s_sd(peer)];
		}
	} else {
		send(userdata, data);
		recv(sd, recv_handler, userdata);
	}
}

listen(LOCAL_ADDRESS, LOCAL_PORT, accept_handler);

event_loop();
