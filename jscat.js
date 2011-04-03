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
	write_bufs: {},
	events: [],

	/* Register/unregister descriptors and operations with the selector.
	   These assume that only one ops of each type is registered per
	   descriptor; for example, you can't register two read events, because
	   when one is unregistered it will unregister the other. The exception
	   to this is that there may be multiple write events per descriptor. */
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

	s_sd: function(sd) {
		var s = sd.socket();
		return [s.getLocalAddress().getHostAddress(),
			s.getLocalPort(),
			s.getInetAddress().getHostAddress(),
			s.getPort()].join("\0");
	},

	handle_selection_key: function(key) {
		var channel = key.channel();
		if ((key.readyOps() & java.nio.channels.SelectionKey.OP_ACCEPT)
			== java.nio.channels.SelectionKey.OP_ACCEPT) {
			this.op_accept(channel);
		} else if ((key.readyOps() & java.nio.channels.SelectionKey.OP_CONNECT)
			== java.nio.channels.SelectionKey.OP_CONNECT) {
			this.op_connect(channel);
		} else if ((key.readyOps() & java.nio.channels.SelectionKey.OP_READ)
			== java.nio.channels.SelectionKey.OP_READ) {
			this.op_read(channel);
		} else if ((key.readyOps() & java.nio.channels.SelectionKey.OP_WRITE)
			== java.nio.channels.SelectionKey.OP_WRITE) {
			this.op_write(channel);
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
		/* For accept only, do not unregister the selection key. */
	},
	op_connect: function(channel) {
		try {
			if (channel.isConnectionPending())
				channel.finishConnect();
		} catch (error) {
			this.events.push({
				type: "connect",
				sd: channel,
				error: error,
			});
			return;
		}
		this.events.push({
			type: "connect",
			sd: channel,
			address: channel.socket().getInetAddress().getHostAddress(),
			port: channel.socket().getPort(),
		});
		this.unregister(channel, java.nio.channels.SelectionKey.OP_CONNECT);
	},
	op_read: function(channel) {
		this.read_buf.clear();
		try {
			var n = channel.read(this.read_buf);
		} catch (error) {
			this.events.push({
				type: "recv",
				sd: channel,
				error: error,
			});
			return;
		}
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
		this.unregister(channel, java.nio.channels.SelectionKey.OP_READ);
	},
	op_write: function(channel) {
		var write_bufs = this.write_bufs[this.s_sd(channel)];
		try {
			var n = channel.write(write_bufs[0]);
		} catch (error) {
			this.events.push({
				type: "send",
				sd: channel,
				error: error,
			});
			return;
		}
		/* Each buffer in our write_bufs queue corresponds to one write
		   event. Don't signal completion until an entire buffer is
		   exhausted. */
		if (write_bufs[0].remaining() == 0) {
			this.events.push({
				type: "send",
				sd: channel,
				n: write_bufs[0].position(),
			});
			write_bufs.shift();
		}
		if (write_bufs.length == 0)
			this.unregister(channel, java.nio.channels.SelectionKey.OP_WRITE);
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
		try {
			sd.socket().bind(java.net.InetSocketAddress(port));
			this.register(sd, java.nio.channels.SelectionKey.OP_ACCEPT);
		} catch (error) {
			this.events.push({
				type: "accept",
				sd: sd,
				error: error,
				address: address,
				port: port,
			});
		}
		return sd;
	},
	connect: function(address, port) {
		var sd = java.nio.channels.SocketChannel.open();
		sd.configureBlocking(false);
		sd.connect(java.net.InetSocketAddress(address, port));
		this.register(sd, java.nio.channels.SelectionKey.OP_CONNECT);
		return sd;
	},
	recv: function(sd) {
		sd.configureBlocking(false);
		this.register(sd, java.nio.channels.SelectionKey.OP_READ);
		return sd;
	},
	send: function(sd, data) {
		sd.configureBlocking(false);
		var key = this.s_sd(sd);
		this.write_bufs[key] = this.write_bufs[key] || [];
		this.write_bufs[key].push(this.string_to_bytebuffer(data));
		this.register(sd, java.nio.channels.SelectionKey.OP_WRITE);
		return sd;
	},
	close: function(sd) {
		delete this.write_bufs[this.s_sd(sd)];
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
			/* "accept" events are persistent; don't remove pending
			   except on closing. */
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
		args = [ev.sd, ev.error, pending.userdata].concat(args);
		if (pending.callback)
			pending.callback.apply(null, args);
	}
}


io.print("jscat starting.")

var LOCAL_ADDRESS = "0.0.0.0";
var LOCAL_PORT = 9998;

var DIRECTORY_ADDRESS = "localhost";
var DIRECTORY_PORT = 9999;

function accept_handler(sd, error, userdata, client, address, port) {
	if (error) {
		io.print("Error listening on " + address + ":" + port + ": " + error.message);
		return;
	}
	io.print("Connection from " + address + ":" + port + ".");
	/* Pass the client as userdata. */
	connect(DIRECTORY_ADDRESS, DIRECTORY_PORT, connect_handler, client);
}

function connect_handler(sd, error, userdata, address, port) {
	if (error) {
		io.print("Error in connect: " + error.message);
		close(userdata);
		return;
	}
	io.print("Connection to " + address + ":" + port + ".");
	/* Queue initial read events. */
	recv(sd, recv_handler, userdata);
	recv(userdata, recv_handler, sd);
}

function recv_handler(sd, error, userdata, data) {
	if (error) {
		io.print("Error in recv: " + error.message);
		close(sd);
		close(userdata);
		return;
	}
	if (data == undefined) {
		close(sd);
		close(userdata);
	} else {
		send(userdata, data);
		recv(sd, recv_handler, userdata);
	}
}

listen(LOCAL_ADDRESS, LOCAL_PORT, accept_handler);

event_loop();
