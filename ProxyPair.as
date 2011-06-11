package
{
    import flash.errors.IllegalOperationError;
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
    
    import swfcat;
    
    public class ProxyPair extends EventDispatcher
    {
        private var ui:swfcat;
        
        protected var client_addr:Object;
        
        /* Not defined here: subclasses should define their own
         * protected var client_socket:Object;
         */
         
        private var c2r_schedule:Array;
        
        private var relay_addr:Object;
        private var relay_socket:Socket;
        private var r2c_schedule:Array;
        
        // Callback id.
        private var flush_id:uint;
        
        public function ProxyPair(self:ProxyPair, ui:swfcat)
        {
            if (self != this) {
                //only a subclass can pass a valid reference to self
            	throw new IllegalOperationError("ProxyPair cannot be instantiated directly.");
            }
            
            this.ui = ui;
            this.c2r_schedule = new Array();
            this.r2c_schedule = new Array();
            
            setup_relay_socket();
            
            /* client_socket setup should be taken */
            /* care of in the subclass constructor */
        }
        
        public function close():void
        {
            if (relay_socket != null && relay_socket.connected) {
                relay_socket.close();
            }
            
            /* subclasses should override to close */
            /* their client_socket according to impl. */
        }
        
        public function get connected():Boolean
        {
            return (relay_socket != null && relay_socket.connected);
            
            /* subclasses should override to check */
            /* connectivity of their client_socket. */
        }
        
        public function set client(client_addr:Object):void
        {
            /* subclasses should override to */
            /* connect the client_socket here */
        }
        
        public function set relay(relay_addr:Object):void
        {
            this.relay_addr = relay_addr;
            log("Relay: connecting to " + relay_addr.host + ":" + relay_addr.port + ".");
            relay_socket.connect(relay_addr.host, relay_addr.port);
        }
        
        protected function transfer_bytes(src:Object, dst:Object, num_bytes:uint):void
        {
            /* No-op: must be overridden by subclasses */
        }

        protected function socket_error(message:String):Function
        {
            return function(e:Event):void {
                if (e is TextEvent)
                    log(message + ": " + (e as TextEvent).text + ".");
                else
                    log(message + ".");
                close();
            };
        }
        
        private function setup_relay_socket():void
        {
            relay_socket = new Socket();
            relay_socket.addEventListener(Event.CONNECT, function (e:Event):void {
                log("Relay: connected to " + relay_addr.host + ":" + relay_addr.port + ".");
                if (connected) {
                    dispatchEvent(new Event(Event.CONNECT));
                }
            });
            relay_socket.addEventListener(Event.CLOSE, socket_error("Relay: closed"));
            relay_socket.addEventListener(IOErrorEvent.IO_ERROR, socket_error("Relay: I/O error"))
            relay_socket.addEventListener(SecurityErrorEvent.SECURITY_ERROR, socket_error("Relay: security error"))
            relay_socket.addEventListener(ProgressEvent.SOCKET_DATA, relay_to_client);
        }
        
        protected function client_to_relay(e:ProgressEvent):void
        {
            c2r_schedule.push(e.bytesLoaded);
            flush();
        }
        
        private function relay_to_client(e:ProgressEvent):void
        {
            r2c_schedule.push(e.bytesLoaded);
            flush();
        }
        
        /* Send as much data as the rate limit currently allows. */
        private function flush():void
        {
            if (flush_id)
                clearTimeout(flush_id);
            flush_id = undefined;

            if (!connected)
                /* Can't do anything until connected. */
                return;

            while (!ui.rate_limit.is_limited() && (c2r_schedule.length > 0 || r2c_schedule.length > 0)) {
                var num_bytes:uint;
                
                if (c2r_schedule.length > 0) {
                    num_bytes = c2r_schedule.shift();
                    transfer_bytes(null, relay_socket, num_bytes);
                    ui.rate_limit.update(num_bytes);
                }
                
                if (r2c_schedule.length > 0) {
                    num_bytes = r2c_schedule.shift();
                    transfer_bytes(relay_socket, null, num_bytes);
                    ui.rate_limit.update(num_bytes);
                }
            }

            /* Call again when safe, if necessary. */
            if (c2r_schedule.length > 0 || r2c_schedule.length > 0)
                flush_id = setTimeout(flush, ui.rate_limit.when() * 1000);
        }
        
        /* Helper function to write output to the
         * swfcat console. Set as protected for
         * subclasses */
        protected function log(s:String):void
        {
            ui.puts(s);
        }
    }
}
