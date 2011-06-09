package
{
    import flash.events.Event;
    import flash.events.EventDispatcher;
    import flash.events.ProgressEvent;
    import flash.net.Socket;
    import flash.utils.ByteArray;
    
    import rtmfp.CirrusSocket;
    import rtmfp.RTMFPSocket;
    import rtmfp.events.RTMFPSocketEvent;
    
    public class RTMFPProxyPair extends ProxyPair
    {
        private var cirrus_socket:CirrusSocket;
        private var client_socket:RTMFPSocket;
        private var listen_stream:String;
        
        public function RTMFPProxyPair(ui:swfcat, cirrus_socket:CirrusSocket, listen_stream:String)
        {
            super(this, ui);
            
            log("Starting RTMFP proxy pair on stream " + listen_stream);
            
            this.cirrus_socket = cirrus_socket;
            this.listen_stream = listen_stream;
            
            setup_client_socket();
        }
        
        override public function set client(client_addr:Object):void
        {
            this.client_addr = client_addr;
            log("Client: connecting to " + client_addr.peer + " on stream " + client_addr.stream + ".");
            client_socket.connect(client_addr.peer, client_addr.stream);
        }
        
        override public function close():void
        {
            super.close();
            if (client_socket != null && client_socket.connected) {
                client_socket.close();
            }
            dispatchEvent(new Event(Event.CLOSE));
        }
        
        override public function get connected():Boolean
        {
            return (super.connected && client_socket != null && client_socket.connected);
        }
        
        override protected function transfer_bytes(src:Object, dst:Object, num_bytes:uint):void
        {
            var bytes:ByteArray = new ByteArray();
            
            if (src == null) {
                src = client_socket;
                RTMFPSocket(src).readBytes(bytes, 0, num_bytes);
                log("RTMFPProxyPair: read " + num_bytes + " bytes from client, writing to relay.");
                Socket(dst).writeBytes(bytes);
            }
            
            if (dst == null) {
                dst = client_socket;
                Socket(src).readBytes(bytes, 0, num_bytes);
                log("RTMFPProxyPair: read " + num_bytes + " bytes from relay, writing to client.");
                RTMFPSocket(dst).writeBytes(bytes);
            }
        }
        
        private function setup_client_socket():void
        {
            client_socket = new RTMFPSocket(cirrus_socket);
            client_socket.addEventListener(RTMFPSocketEvent.CONNECT_FAILED, function (e:RTMFPSocketEvent):void {
                log("Client: connection failed to " + client_addr.peer + " on stream " + client_addr.stream + ".");
            });
            client_socket.addEventListener(RTMFPSocketEvent.CONNECT_SUCCESS, function (e:RTMFPSocketEvent):void {
                log("Client: connected to " + client_addr.peer + " on stream " + client_addr.stream + ".");
                if (connected) {
                    dispatchEvent(new Event(Event.CONNECT));
                }
            });
            client_socket.addEventListener(RTMFPSocketEvent.PEER_CONNECTED, function (e:RTMFPSocketEvent):void {
                log("Peer connected.");
            });
            client_socket.addEventListener(RTMFPSocketEvent.PEER_DISCONNECTED, function (e:RTMFPSocketEvent):void {
                log("Client: disconnected from " + client_addr.peer + ".");
                close();
            });
            client_socket.addEventListener(RTMFPSocketEvent.PLAY_STARTED, function (e:RTMFPSocketEvent):void {
                log("Play started.");
            });
            client_socket.addEventListener(RTMFPSocketEvent.PUBLISH_STARTED, function (e:RTMFPSocketEvent):void {
                log("Publishing started.");
            });
            client_socket.addEventListener(ProgressEvent.SOCKET_DATA, client_to_relay);
            
            client_socket.listen(listen_stream);
        }
    }
}