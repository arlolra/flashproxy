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
        // Label for log messages.
        public var name:String;

        // Socket to client.
        private var s_c:*;
        private var connect_c:Function;

        // Socket to relay.
        private var s_r:*;
        private var connect_r:Function;

        // Parent swfcat, for UI updates and rate meter.
        private var ui:swfcat;

        // Pending byte read counts for relay and client sockets.
        private var r2c_schedule:Array;
        private var c2r_schedule:Array;
        // Callback id.
        private var flush_id:uint;

        public function log(msg:String):void
        {
            if (name)
                ui.puts(name + ": " + msg)
            else
                ui.puts(msg)
        }

        public function logdebug(msg:String):void
        {
            if (ui.debug)
                log(msg);
        }

        public function set_name(name:String):void
        {
            this.name = name;
        }

        public function ProxyPair(ui:swfcat, s_c:*, connect_c:Function, s_r:*, connect_r:Function)
        {
            this.ui = ui;
            /* s_c is a socket for connecting to the client. connect_c is a
               function that, when called, connects s_c. Likewise for s_r and
               connect_r. */
            this.s_c = s_c;
            this.connect_c = connect_c;
            this.s_r = s_r;
            this.connect_r = connect_r;

            this.c2r_schedule = [];
            this.r2c_schedule = [];
        }

        /* Return a function that shows an error message and closes the other half
           of a communication pair. */
        private function socket_error(message:String, other:*):Function
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
            s_r.addEventListener(Event.CONNECT, relay_connected);
            s_r.addEventListener(Event.CLOSE, relay_closed);
            s_r.addEventListener(IOErrorEvent.IO_ERROR, socket_error("Relay: I/O error", s_c));
            s_r.addEventListener(SecurityErrorEvent.SECURITY_ERROR, socket_error("Relay: security error", s_c));
            s_r.addEventListener(ProgressEvent.SOCKET_DATA, relay_to_client);

            s_c.addEventListener(Event.CONNECT, client_connected);
            s_c.addEventListener(Event.CLOSE, client_closed);
            s_c.addEventListener(IOErrorEvent.IO_ERROR, socket_error("Client: I/O error", s_r));
            s_c.addEventListener(SecurityErrorEvent.SECURITY_ERROR, socket_error("Client: security error", s_r));
            s_c.addEventListener(ProgressEvent.SOCKET_DATA, client_to_relay);

            log("Relay: connecting.");
            connect_r();
            log("Client: connecting.");
            connect_c();
        }

        private function relay_connected(e:Event):void
        {
            log("Relay: connected.");
        }

        private function client_connected(e:Event):void
        {
            log("Client: connected.");
        }

        private function relay_closed(e:Event):void
        {
            log("Relay: closed.");
            flush();
        }

        private function client_closed(e:Event):void
        {
            log("Client: closed.");
            flush();
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

        private function transfer_chunk(s_from:*, s_to:*, n:uint,
            label:String):void
        {
            var bytes:ByteArray;

            bytes = new ByteArray();
            s_from.readBytes(bytes, 0, n);
            s_to.writeBytes(bytes);
            s_to.flush();
            ui.rate_limit.update(n);
            logdebug(label + ": read " + bytes.length + ".");
        }

        /* Send as much data as the rate limit currently allows. */
        private function flush():void
        {
            var busy:Boolean;

            if (flush_id)
                clearTimeout(flush_id);
            flush_id = undefined;

            if (!s_r.connected && !s_c.connected)
                /* Can't do anything while both sockets are disconnected. */
                return;

            busy = true;
            while (busy && !ui.rate_limit.is_limited()) {
                busy = false;
                if (s_c.connected && r2c_schedule.length > 0) {
                    transfer_chunk(s_r, s_c, r2c_schedule.shift(), "Relay");
                    busy = true;
                }
                if (s_r.connected && c2r_schedule.length > 0) {
                    transfer_chunk(s_c, s_r, c2r_schedule.shift(), "Client");
                    busy = true;
                }
            }

            if (!s_r.connected && r2c_schedule.length == 0) {
                log("Client: closing.");
                s_c.close();
            }
            if (!s_c.connected && c2r_schedule.length == 0) {
                log("Relay: closing.");
                s_r.close();
            }

            if (!s_c.connected && !s_r.connected)
                dispatchEvent(new Event(Event.COMPLETE));
            else if (r2c_schedule.length > 0 || c2r_schedule.length > 0)
                flush_id = setTimeout(flush, ui.rate_limit.when() * 1000);
        }
    }
}
