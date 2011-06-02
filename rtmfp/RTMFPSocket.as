package rtmfp
{
    import flash.events.Event;
    import flash.events.EventDispatcher;
    import flash.events.IOErrorEvent;
    import flash.events.NetStatusEvent;
    import flash.events.ProgressEvent;
    import flash.events.SecurityErrorEvent;
    import flash.net.NetConnection;
    import flash.net.NetStream;
    import flash.utils.ByteArray;
    import flash.utils.clearTimeout;
    import flash.utils.setTimeout;
    
    import rtmfp.CirrusSocket;
    import rtmfp.RTMFPSocketClient;
    import rtmfp.events.CirrusSocketEvent;
    import rtmfp.events.RTMFPSocketEvent;
    
    [Event(name=RTMFPSocketEvent.CONNECT_FAILED, type="com.flashproxy.rtmfp.events.RTMFPSocketEvent")]
    [Event(name=RTMFPSocketEvent.CONNECT_CLOSED, type="com.flashproxy.rtmfp.events.RTMFPSocketEvent")]
    [Event(name=RTMFPSocketEvent.CONNECT_SUCCESS, type="com.flashproxy.rtmfp.events.RTMFPSocketEvent")]
    [Event(name=RTMFPSocketEvent.PEER_CONNECTED, type="com.flashproxy.rtmfp.events.RTMFPSocketEvent")]
    [Event(name=RTMFPSocketEvent.PEER_DISCONNECTED, type="com.flashproxy.rtmfp.events.RTMFPSocketEvent")]
    [Event(name=RTMFPSocketEvent.PLAY_STARTED, type="com.flashproxy.rtmfp.events.RTMFPSocketEvent")]
    [Event(name=RTMFPSocketEvent.PUBLISH_STARTED, type="com.flashproxy.rtmfp.events.RTMFPSocketEvent")]
    [Event(name=RTMFPSocketEvent.PUBLISH_FAILED, type="com.flashproxy.rtmfp.events.RTMFPSocketEvent")]
    public class RTMFPSocket extends EventDispatcher
    {		
        private const CONNECT_TIMEOUT:uint = 10000;
	
        private var s_c:CirrusSocket;
        
	private var recv_stream:NetStream;
        private var send_stream:NetStream;

        private var peer_stream:NetStream;

	private var connect_timeout:int;
        
        public function RTMFPSocket(s_c:CirrusSocket)
        {
            this.s_c = s_c;
            recv_stream = null;
	    send_stream = null;
    	    connect_timeout = 0;
        }
        
	/* Tears down this RTMFPSocket, closing both its streams.
	   To be used when destroying this object. */
	public function close():void
        {
            if (send_stream != null) {
                s_c.connection.removeEventListener(NetStatusEvent.NET_STATUS, on_stream_disconnection_event);
                send_stream.close();
            }
            
            if (recv_stream != null) {
                recv_stream.close();
            }
        }

        /* In RTMFP, you connect to a remote socket by requesting to
           "play" the data being published on a named stream by the
           host identified by id. The connection request goes through
           the Cirrus server which handles the mapping from id/stream
           to IP/port and any necessary NAT traversal. */
        public function connect(id:String, stream:String):void
        {
            recv_stream = new NetStream(s_c.connection, id);
            var client:RTMFPSocketClient = new RTMFPSocketClient();
            client.addEventListener(ProgressEvent.SOCKET_DATA, on_data_available, false, 0, true);
            client.addEventListener(RTMFPSocketClient.CONNECT_ACKNOWLEDGED, on_connect_acknowledged, false, 0, true);
            recv_stream.client = client;
            recv_stream.addEventListener(NetStatusEvent.NET_STATUS, on_recv_stream_event);
            recv_stream.play(stream);
            connect_timeout = setTimeout(on_connect_timeout, CONNECT_TIMEOUT, recv_stream);
        }
        
        public function get connected():Boolean
        {
            return (recv_stream != null && recv_stream.client != null &&
                    RTMFPSocketClient(recv_stream.client).connect_acknowledged);
        }

	/* In RTMFP, you open a listening socket by publishing a named
           stream that others can connect to instead of listening on a port.
           You register this stream with the Cirrus server via the Cirrus
           socket so that it can redirect connection requests for an id/stream
           tuple to this socket. */
        public function listen(stream:String):void
        {
            // apparently streams don't get disconnection events, only the NetConnection
            // object does...bleh.
            s_c.connection.addEventListener(NetStatusEvent.NET_STATUS, on_stream_disconnection_event);
        
            send_stream = new NetStream(s_c.connection, NetStream.DIRECT_CONNECTIONS);
            send_stream.addEventListener(NetStatusEvent.NET_STATUS, on_send_stream_event);	
            var client:Object = new Object();
            client.onPeerConnect = on_peer_connect;
            send_stream.client = client;
            send_stream.publish(stream);
        }
        
        public function get peer():String
        {
            if (!connected) return null;
            return recv_stream.farID;
        }
        
        public function get peer_connected():Boolean
        {
            return send_stream.peerStreams.length > 0;
        }
        
        public function readBytes(bytes:ByteArray, offset:uint = 0, length:uint = 0):void
        {
	    if (recv_stream != null && recv_stream.client != null) {
		recv_stream.client.bytes.readBytes(bytes, offset, length);
	    }   
        }

        public function writeBytes(bytes:ByteArray):void
        {
            if (send_stream != null && peer_connected) {
		send_stream.send(RTMFPSocketClient.DATA_AVAILABLE, bytes);
	    }
        }
        
        /* Listens for acknowledgement of a connection attempt to a
           remote peer. */
        private function on_connect_acknowledged(event:Event):void
        {
            clearTimeout(connect_timeout);
	    dispatchEvent(new RTMFPSocketEvent(RTMFPSocketEvent.CONNECT_SUCCESS, recv_stream));
        }

        /* If we don't get a connection acknowledgement by the time this
           timeout function is called, we punt. */
        private function on_connect_timeout(peer:NetStream):void
        {
            if (!this.connected) {
                dispatchEvent(new RTMFPSocketEvent(RTMFPSocketEvent.CONNECT_FAILED, recv_stream));
            }
        }
        
        private function on_data_available(event:ProgressEvent):void
        {
            dispatchEvent(event);
        }
        
        private function on_recv_stream_event(event:NetStatusEvent):void
        {
            /* empty, here for symmetry */
        }

        /* This function gets called whenever someone tries to connect
           to this socket's send_stream tuple. We don't want multiple
           peers connecting at once, so we disallow that. The socket
           acknowledges the connection back to the peer with the
           SET_CONNECTION_ACKNOWLEDGED message. */
        private function on_peer_connect(peer:NetStream):Boolean
        {
            if (peer_connected) {
                return false;
            }
            
            peer_stream = peer;
            peer.send(RTMFPSocketClient.SET_CONNECT_ACKNOWLEDGED);
            
            // need to do this in a timeout so that this function can
            // return true to finalize the connection before firing the event
            setTimeout(function (stream:NetStream):void {
                dispatchEvent(new RTMFPSocketEvent(RTMFPSocketEvent.PEER_CONNECTED, stream));
            }, 0, peer);
            
            return true;
        }
        
        private function on_send_stream_event(event:NetStatusEvent):void
        {
            switch (event.info.code) {
                case "NetStream.Publish.Start":
                    dispatchEvent(new RTMFPSocketEvent(RTMFPSocketEvent.PUBLISH_STARTED));
                    break;
                case "NetStream.Publish.BadName":
                    dispatchEvent(new RTMFPSocketEvent(RTMFPSocketEvent.PUBLISH_FAILED));
                    break;
                default:
                    break;
            }
        }
        
        private function on_stream_disconnection_event(event:NetStatusEvent):void
        {
            if (event.info.code == "NetStream.Connect.Closed" && event.info.stream === peer_stream) {
                dispatchEvent(new RTMFPSocketEvent(RTMFPSocketEvent.PEER_DISCONNECTED));
            }
        }
    }
}

