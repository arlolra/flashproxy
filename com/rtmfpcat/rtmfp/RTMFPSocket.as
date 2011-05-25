/* RTMFPSocket abstraction
 * Author: Nate Hardison, May 2011
 * 
 * This code is heavily based off of BelugaFile, an open-source
 * Air file-transfer application written by Nicholas Bliyk.
 * Website: http://www.belugafile.com/
 * Source: http://code.google.com/p/belugafile/ 
 *
 */

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
    import flash.utils.clearInterval;
    import flash.utils.setInterval;
    import flash.utils.setTimeout;
    
    import rtmfp.RTMFPSocketClient;
    import rtmfp.events.RTMFPSocketEvent;

    [Event(name="connectSuccess", type="com.jscat.rtmfp.events.RTMFPSocketEvent")]
    [Event(name="connectFail", type="com.jscat.rtmfp.events.RTMFPSocketEvent")]
    [Event(name="publishStart", type="com.jscat.rtmfp.events.RTMFPSocketEvent")]
    [Event(name="peerConnected", type="com.jscat.rtmfp.events.RTMFPSocketEvent")]
    [Event(name="peeringSuccess", type="com.jscat.rtmfp.events.RTMFPSocketEvent")]
    [Event(name="peeringFail", type="com.jscat.rtmfp.events.RTMFPSocketEvent")]
    [Event(name="peerDisconnected", type="com.jscat.rtmfp.events.RTMFPSocketEvent")]
    public class RTMFPSocket extends EventDispatcher
    {
        /* The name of the "media" to pass between peers */
        private static const DATA:String = "data";
        private static const DEFAULT_CIRRUS_ADDRESS:String = "rtmfp://p2p.rtmfp.net";
        private static const DEFAULT_CIRRUS_KEY:String = RTMFP::CIRRUS_KEY;
        private static const DEFAULT_CONNECT_TIMEOUT:uint = 4000;
    
        /* Connection to the Cirrus rendezvous service */
        private var connection:NetConnection;
    
        /* ID of the peer to connect to */
        private var peerID:String;
    
        /* Data streams to be established with peer */
        private var sendStream:NetStream;
        private var recvStream:NetStream;
        
        /* Timeouts */
        private var connectionTimeout:int;
        private var peerConnectTimeout:uint;

        public function RTMFPSocket(){}
        
        public function connect(addr:String = DEFAULT_CIRRUS_ADDRESS, key:String = DEFAULT_CIRRUS_KEY):void
        {
            connection = new NetConnection();
            connection.addEventListener(NetStatusEvent.NET_STATUS, onNetStatusEvent);
            connection.addEventListener(IOErrorEvent.IO_ERROR, onIOErrorEvent);
            connection.addEventListener(SecurityErrorEvent.SECURITY_ERROR, onSecurityErrorEvent);
            connection.connect(addr + "/" + key);
            connectionTimeout = setInterval(fail, DEFAULT_CONNECT_TIMEOUT);
        }

        public function close():void
        {
            connection.close();
        }

        public function get id():String
        {
            if (connection != null && connection.connected) {
                return connection.nearID;
            }
          
            return null;
        }
        
        public function get connected():Boolean
        {
            return (connection != null && connection.connected);
        }
        
        public function readBytes(bytes:ByteArray):void
        {
            recvStream.client.bytes.readBytes(bytes);
        }

        public function writeBytes(bytes:ByteArray):void
        {
            sendStream.send("dataAvailable", bytes);
        }
        
        public function get peer():String
        {
            return this.peerID;
        }

        public function set peer(peerID:String):void
        {
            if (peerID == null || peerID.length == 0) {
                throw new Error("Peer ID is null/empty.")
            } else if (peerID == connection.nearID) {
                throw new Error("Peer ID cannot be the same as our ID.");
            } else if (this.peerID == peerID) {
                throw new Error("Already connected to peer " + peerID + ".");
            } else if (this.recvStream != null) {
                throw new Error("Cannot connect to a second peer.");
            }
          
            this.peerID = peerID;

            recvStream = new NetStream(connection, peerID);
            var client:RTMFPSocketClient = new RTMFPSocketClient();
            client.addEventListener(ProgressEvent.SOCKET_DATA, onDataAvailable, false, 0, true);
            client.addEventListener(RTMFPSocketClient.PEER_CONNECT_ACKNOWLEDGED, onPeerConnectAcknowledged, false, 0, true);
            recvStream.client = client;
            recvStream.addEventListener(NetStatusEvent.NET_STATUS, onRecvStreamEvent);
            recvStream.play(DATA);
            setTimeout(onPeerConnectTimeout, peerConnectTimeout, recvStream);
        }
        
        private function startPublishStream():void
        {
            sendStream = new NetStream(connection, NetStream.DIRECT_CONNECTIONS);
            sendStream.addEventListener(NetStatusEvent.NET_STATUS, onSendStreamEvent);
            var o:Object = new Object();
            o.onPeerConnect = onPeerConnect;
            sendStream.client = o;
            sendStream.publish(DATA);
        }
        
        private function fail():void
        {
            clearInterval(connectionTimeout);
            dispatchEvent(new RTMFPSocketEvent(RTMFPSocketEvent.CONNECT_FAIL));
        }
        
        private function onDataAvailable(event:ProgressEvent):void
        {
            dispatchEvent(event);
        }
        
        private function onIOErrorEvent(event:IOErrorEvent):void
        {
            fail();
        }
        
        private function onNetStatusEvent(event:NetStatusEvent):void
        {
            switch (event.info.code) {
                case "NetConnection.Connect.Success" :
                    clearInterval(connectionTimeout);
                    startPublishStream();
                    dispatchEvent(new RTMFPSocketEvent(RTMFPSocketEvent.CONNECT_SUCCESS));
                    break;
                case "NetStream.Connect.Success" :
                    break;
                case "NetStream.Publish.BadName" :
                    fail();
                    break;
                case "NetStream.Connect.Closed" :
                    // we've disconnected from the peer
                    // can reset to accept another
                    // clear the publish stream and re-publish another
                    dispatchEvent(new RTMFPSocketEvent(RTMFPSocketEvent.PEER_DISCONNECTED, recvStream));
                    break;
            } 
        }
        
        private function onPeerConnect(peer:NetStream):Boolean
        {
            // establish a bidirectional stream with the peer
            if (peerID == null) {
                this.peer = peer.farID;
            }
          
            // disallow additional peers connecting to us
            if (peer.farID != peerID) return false;
          
            peer.send("setPeerConnectAcknowledged");
            dispatchEvent(new RTMFPSocketEvent(RTMFPSocketEvent.PEER_CONNECTED, peer));
          
            return true;
        }
        
        private function onPeerConnectAcknowledged(event:Event):void
        {
            dispatchEvent(new RTMFPSocketEvent(RTMFPSocketEvent.PEERING_SUCCESS, recvStream));
        }
        
        private function onPeerConnectTimeout(peer:NetStream):void
        {
            if (!recvStream.client) return;
            if (!RTMFPSocketClient(recvStream.client).peerConnectAcknowledged) {
                dispatchEvent(new RTMFPSocketEvent(RTMFPSocketEvent.PEERING_FAIL, recvStream));
            }
        }
        
        private function onSecurityErrorEvent(event:SecurityErrorEvent):void
        {
            fail();
        }
        
        private function onSendStreamEvent(event:NetStatusEvent):void
        {
            switch (event.info.code) {
                case ("NetStream.Publish.Start") :
                    dispatchEvent(new RTMFPSocketEvent(RTMFPSocketEvent.PUBLISH_START));
                    break;
                case ("NetStream.Play.Reset") :
                case ("NetStream.Play.Start") :
                    break;
            }
        }

        private function onRecvStreamEvent(event:NetStatusEvent):void
        {
            switch (event.info.code) {
                case ("NetStream.Publish.Start") :
                case ("NetStream.Play.Reset") :
                case ("NetStream.Play.Start") :
                    break;
            }
        }
    }
}
