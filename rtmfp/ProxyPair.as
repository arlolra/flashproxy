package rtmfp
{
    import flash.events.Event;
    import flash.events.EventDispatcher;
    import flash.events.IOErrorEvent;
    import flash.events.ProgressEvent;
    import flash.events.SecurityErrorEvent;
    import flash.net.Socket;
    import flash.utils.ByteArray;
    
    import rtmfp.CirrusSocket;
    import rtmfp.RTMFPSocket;
    import rtmfp.events.RTMFPSocketEvent;
    
    public class ProxyPair extends EventDispatcher
    {   
        private var parent:rtmfpcat;

        private var s_r:RTMFPSocket;
        private var s_t:Socket;
        
        private var tor_host:String;
        private var tor_port:uint;

        public function ProxyPair(parent:rtmfpcat, s_c:CirrusSocket, tor_host:String, tor_port:uint)
        {
            this.parent = parent;
            this.tor_host = tor_host;
            this.tor_port = tor_port;
            
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
            s_r.addEventListener(RTMFPSocketEvent.PLAY_STARTED, function (e:RTMFPSocketEvent):void {
                puts("Play started.");
            });
            s_r.addEventListener(RTMFPSocketEvent.PUBLISH_STARTED, function (e:RTMFPSocketEvent):void {
                puts("Publishing started.");
            });
            s_r.addEventListener(RTMFPSocketEvent.PEER_CONNECTED, function (e:RTMFPSocketEvent):void {
                puts("Peer connected.");
            });
            s_r.addEventListener(RTMFPSocketEvent.PEER_DISCONNECTED, function (e:RTMFPSocketEvent):void {
                puts("Peer disconnected.");
                close();
            });
            s_r.addEventListener(RTMFPSocketEvent.CONNECT_SUCCESS, function (e:RTMFPSocketEvent):void {
                puts("Peering success.");
                s_t.connect(tor_host, tor_port);
            });
            s_r.addEventListener(RTMFPSocketEvent.CONNECT_FAILED, function (e:RTMFPSocketEvent):void {
                puts("Peering failed.");
            });
        }
        
        private function setup_tor_socket():void
        {
            s_t = new Socket();
            s_t.addEventListener(Event.CONNECT, function (e:Event):void {
                puts("Tor: connected to " + tor_host + ":" + tor_port + ".");
                s_t.addEventListener(ProgressEvent.SOCKET_DATA, function (e:ProgressEvent):void {
                    var bytes:ByteArray = new ByteArray();
                    s_t.readBytes(bytes, 0, e.bytesLoaded);
                    puts("RTMFPSocket: Tor: read " + bytes.length + " bytes.");
                    s_r.writeBytes(bytes);
                });
                s_r.addEventListener(ProgressEvent.SOCKET_DATA, function (e:ProgressEvent):void {
                    var bytes:ByteArray = new ByteArray();
                    s_r.readBytes(bytes, 0, e.bytesLoaded);
                    puts("RTMFPSocket: RTMFP: read " + bytes.length + " bytes.");
                    s_t.writeBytes(bytes);
                });
                dispatchEvent(new Event(Event.CONNECT));
            });
            s_t.addEventListener(Event.CLOSE, function (e:Event):void {
                puts("Tor: closed connection.");
                close();
            });
            s_t.addEventListener(IOErrorEvent.IO_ERROR, function (e:IOErrorEvent):void {
                puts("Tor: I/O error: " + e.text + ".");
                close();
            });
            s_t.addEventListener(SecurityErrorEvent.SECURITY_ERROR, function (e:SecurityErrorEvent):void {
                puts("Tor: security error: " + e.text + ".");
                close();
            });
        }
        
        private function puts(s:String):void
        {
            parent.puts(s);
        }
        
    }
}