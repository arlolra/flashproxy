package
{
    import flash.events.Event;
    import flash.events.EventDispatcher;
    import flash.events.IOErrorEvent;
    import flash.events.ProgressEvent;
    import flash.events.SecurityErrorEvent;
    import flash.events.TextEvent;
    import flash.net.Socket;
    import flash.utils.ByteArray;
    import flash.utils.clearTimeout;
    import flash.utils.setTimeout;

    /* An instance of a client-relay connection. */
    public class ProxyPair extends EventDispatcher
    {
        // Address ({host, port}) of client.
        private var addr_c:Object;
        // Address ({host, port}) of relay.
        private var addr_r:Object;

        // Socket to client.
        private var s_c:Socket;
        // Socket to relay.
        private var s_r:Socket;

        // Parent swfcat, for UI updates and rate meter.
        private var ui:swfcat;

        // Pending byte read counts for relay and client sockets.
        private var r2c_schedule:Array;
        private var c2r_schedule:Array;
        // Callback id.
        private var flush_id:uint;

        public function log(msg:String):void
        {
            ui.puts(id() + ": " + msg)
        }

        // String describing this pair for output.
        public function id():String
        {
            return "<" + this.addr_c.host + ":" + this.addr_c.port +
                "," + this.addr_r.host + ":" + this.addr_r.port + ">";
        }

        public function ProxyPair(ui:swfcat, addr_c:Object, addr_r:Object)
        {
            this.ui = ui;
            this.addr_c = addr_c;
            this.addr_r = addr_r;

            this.c2r_schedule = [];
            this.r2c_schedule = [];
        }

        /* Return a function that shows an error message and closes the other half
           of a communication pair. */
        private function socket_error(message:String, other:Socket):Function
        {
            return function(e:Event):void {
                if (e is TextEvent)
                    log(message + ": " + (e as TextEvent).text + ".");
                else
                    log(message + ".");
                if (other && other.connected)
                    other.close();
                dispatchEvent(new Event(Event.COMPLETE));
            };
        }

        public function connect():void
        {
            s_r = new Socket();

            s_r.addEventListener(Event.CONNECT, relay_connected);
            s_r.addEventListener(Event.CLOSE, socket_error("Relay: closed", s_c));
            s_r.addEventListener(IOErrorEvent.IO_ERROR, socket_error("Relay: I/O error", s_c));
            s_r.addEventListener(SecurityErrorEvent.SECURITY_ERROR, socket_error("Relay: security error", s_c));
            s_r.addEventListener(ProgressEvent.SOCKET_DATA, relay_to_client);

            log("Relay: connecting to " + addr_r.host + ":" + addr_r.port + ".");
            s_r.connect(addr_r.host, addr_r.port);
        }

        private function relay_connected(e:Event):void
        {
            log("Relay: connected.");

            s_c = new Socket();

            s_c.addEventListener(Event.CONNECT, client_connected);
            s_c.addEventListener(Event.CLOSE, socket_error("Client: closed", s_r));
            s_c.addEventListener(IOErrorEvent.IO_ERROR, socket_error("Client: I/O error", s_r));
            s_c.addEventListener(SecurityErrorEvent.SECURITY_ERROR, socket_error("Client: security error", s_r));
            s_c.addEventListener(ProgressEvent.SOCKET_DATA, client_to_relay);

            log("Client: connecting to " + addr_c.host + ":" + addr_c.port + ".");
            s_c.connect(addr_c.host, addr_c.port);
        }

        private function relay_to_client(e:ProgressEvent):void
        {
            r2c_schedule.push(e.bytesLoaded);
            flush();
        }

        private function client_to_relay(e:ProgressEvent):void
        {
            c2r_schedule.push(e.bytesLoaded);
            flush();
        }

        private function client_connected(e:Event):void
        {
            log("Client: connected.");
        }

        private function transfer_chunk(s_from:Socket, s_to:Socket, n:uint,
            label:String):void
        {
            var bytes:ByteArray;

            bytes = new ByteArray();
            s_from.readBytes(bytes, 0, n);
            s_to.writeBytes(bytes);
            ui.rate_limit.update(n);
            log(label + ": read " + bytes.length + ".");
        }

        /* Send as much data as the rate limit currently allows. */
        private function flush():void
        {
            if (flush_id)
                clearTimeout(flush_id);
            flush_id = undefined;

            if (!(s_r.connected && s_c.connected))
                /* Can't do anything until both sockets are connected. */
                return;

            while (!ui.rate_limit.is_limited() &&
                   (r2c_schedule.length > 0 || c2r_schedule.length > 0)) {
                if (r2c_schedule.length > 0)
                    transfer_chunk(s_r, s_c, r2c_schedule.shift(), "Relay");
                if (c2r_schedule.length > 0)
                    transfer_chunk(s_c, s_r, c2r_schedule.shift(), "Client");
            }

            /* Call again when safe, if necessary. */
            if (r2c_schedule.length > 0 || c2r_schedule.length > 0)
                flush_id = setTimeout(flush, ui.rate_limit.when() * 1000);
        }
    }
}
