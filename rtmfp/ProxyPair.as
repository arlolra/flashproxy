package rtmfp
{
    import flash.events.Event;
    import flash.events.EventDispatcher;
    import flash.events.IOErrorEvent;
    import flash.events.ProgressEvent;
    import flash.events.SecurityErrorEvent;
    import flash.net.Socket;
    import flash.utils.ByteArray;
    import flash.utils.clearTimeout;
    import flash.utils.setTimeout;
    
    import rtmfp.CirrusSocket;
    import rtmfp.RTMFPSocket;
    import rtmfp.events.RTMFPSocketEvent;
    
    public class ProxyPair extends EventDispatcher
    {   
        private var ui:rtmfpcat;

        private var s_r:RTMFPSocket;
        private var s_t:Socket;
        
        private var tor_host:String;
        private var tor_port:uint;
        
        private var p2t_schedule:Array;
        private var t2p_schedule:Array;
        
        // Bytes per second. Set to undefined to disable limit.
        public const RATE_LIMIT:Number = 10000;
        // Seconds.
        private const RATE_LIMIT_HISTORY:Number = 5.0;
        
        private var rate_limit:RateLimit;
        
        // Callback id.
        private var flush_id:uint;

        public function ProxyPair(ui:rtmfpcat, s_c:CirrusSocket, tor_host:String, tor_port:uint)
        {
            this.ui = ui;
            this.tor_host = tor_host;
            this.tor_port = tor_port;
            
            this.p2t_schedule = new Array();
            this.t2p_schedule = new Array();
            
            if (RATE_LIMIT)
                rate_limit = new BucketRateLimit(RATE_LIMIT * RATE_LIMIT_HISTORY, RATE_LIMIT_HISTORY);
            else
                rate_limit = new RateUnlimit();
            
            setup_rtmfp_socket(s_c);
            setup_tor_socket();
        }
        
        public function close():void
        {
            if (s_r.connected) {
                s_r.close();
            }
            if (s_t.connected) {
                s_t.close();
            }
            dispatchEvent(new Event(Event.CLOSE));
        }

        public function connect(peer:String, stream:String):void
        {        
            s_r.connect(peer, stream);
        }
        
        public function get connected():Boolean
        {
            return (s_r.connected && s_t.connected);
        }
        
        public function listen(stream:String):void
        {            
            s_r.listen(stream);
        }
        
        private function setup_rtmfp_socket(s_c:CirrusSocket):void
        {
            s_r = new RTMFPSocket(s_c);
            s_r.addEventListener(RTMFPSocketEvent.CONNECT_FAILED, function (e:RTMFPSocketEvent):void {
                ui.puts("Peering failed.");
            });
            s_r.addEventListener(RTMFPSocketEvent.CONNECT_SUCCESS, function (e:RTMFPSocketEvent):void {
                ui.puts("Peering success.");
                s_t.connect(tor_host, tor_port);
            });
            s_r.addEventListener(RTMFPSocketEvent.PEER_CONNECTED, function (e:RTMFPSocketEvent):void {
                ui.puts("Peer connected.");
            });
            s_r.addEventListener(RTMFPSocketEvent.PEER_DISCONNECTED, function (e:RTMFPSocketEvent):void {
                ui.puts("Peer disconnected.");
                close();
            });
            s_r.addEventListener(RTMFPSocketEvent.PLAY_STARTED, function (e:RTMFPSocketEvent):void {
                ui.puts("Play started.");
            });
            s_r.addEventListener(RTMFPSocketEvent.PUBLISH_STARTED, function (e:RTMFPSocketEvent):void {
                ui.puts("Publishing started.");
            });
            s_r.addEventListener(ProgressEvent.SOCKET_DATA, proxy_to_tor);
        }
        
        private function setup_tor_socket():void
        {
            s_t = new Socket();
            s_t.addEventListener(Event.CONNECT, function (e:Event):void {
                ui.puts("Tor: connected to " + tor_host + ":" + tor_port + ".");
                dispatchEvent(new Event(Event.CONNECT));
            });
            s_t.addEventListener(Event.CLOSE, function (e:Event):void {
                ui.puts("Tor: closed connection.");
                close();
            });
            s_t.addEventListener(IOErrorEvent.IO_ERROR, function (e:IOErrorEvent):void {
                ui.puts("Tor: I/O error: " + e.text + ".");
                close();
            });
            s_t.addEventListener(SecurityErrorEvent.SECURITY_ERROR, function (e:SecurityErrorEvent):void {
                ui.puts("Tor: security error: " + e.text + ".");
                close();
            });
            s_t.addEventListener(ProgressEvent.SOCKET_DATA, tor_to_proxy);
        }
        
        private function tor_to_proxy(e:ProgressEvent):void
        {
            t2p_schedule.push(e.bytesLoaded);
            flush();
        }

        private function proxy_to_tor(e:ProgressEvent):void
        {
            p2t_schedule.push(e.bytesLoaded);
            flush();
        }
        
        /* Send as much data as the rate limit currently allows. */
        private function flush():void
        {
            if (flush_id)
                clearTimeout(flush_id);
            flush_id = undefined;

            if (!(s_r.connected && s_t.connected))
                /* Can't do anything until both sockets are connected. */
                return;

            while (!rate_limit.is_limited() && (p2t_schedule.length > 0 || t2p_schedule.length > 0)) {
                var numBytes:uint;
                var bytes:ByteArray;
                
                if (p2t_schedule.length > 0) {
                    numBytes = p2t_schedule.shift();
                    bytes = new ByteArray();
                    s_r.readBytes(bytes, 0, numBytes);
                    ui.puts("ProxyPair: RTMFP: read " + bytes.length + " bytes.");
                    s_t.writeBytes(bytes);
                    rate_limit.update(numBytes);
                }
                if (t2p_schedule.length > 0) {
                    numBytes = t2p_schedule.shift();
                    bytes = new ByteArray();
                    s_t.readBytes(bytes, 0, numBytes);
                    ui.puts("ProxyPair: Tor: read " + bytes.length + " bytes.");
                    s_r.writeBytes(bytes);
                    rate_limit.update(numBytes);
                }
            }

            /* Call again when safe, if necessary. */
            if (p2t_schedule.length > 0 || t2p_schedule.length > 0)
                flush_id = setTimeout(flush, rate_limit.when() * 1000);
        }
    }
}

import flash.utils.getTimer;

class RateLimit
{
    public function RateLimit()
    {
    }

    public function update(n:Number):Boolean
    {
        return true;
    }

    public function when():Number
    {
        return 0.0;
    }

    public function is_limited():Boolean
    {
        return false;
    }
}

class RateUnlimit extends RateLimit
{
    public function RateUnlimit()
    {
    }

    public override function update(n:Number):Boolean
    {
        return true;
    }

    public override function when():Number
    {
        return 0.0;
    }

    public override function is_limited():Boolean
    {
        return false;
    }
}

class BucketRateLimit extends RateLimit
{
    private var amount:Number;
    private var capacity:Number;
    private var time:Number;
    private var last_update:uint;

    public function BucketRateLimit(capacity:Number, time:Number)
    {
        this.amount = 0.0;
        /* capacity / time is the rate we are aiming for. */
        this.capacity = capacity;
        this.time = time;
        this.last_update = getTimer();
    }

    private function age():void
    {
        var now:uint;
        var delta:Number;

        now = getTimer();
        delta = (now - last_update) / 1000.0;
        last_update = now;

        amount -= delta * capacity / time;
        if (amount < 0.0)
            amount = 0.0;
    }

    public override function update(n:Number):Boolean
    {
        age();
        amount += n;

        return amount <= capacity;
    }

    public override function when():Number
    {
        age();
        return (amount - capacity) / (capacity / time);
    }

    public override function is_limited():Boolean
    {
        age();
        return amount > capacity;
    }
}