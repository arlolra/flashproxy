package
{
    import flash.display.Sprite;
    import flash.text.TextField;
    import flash.net.Socket;
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

    public class RTMFPRelay extends Sprite
    {
		    private static const CIRRUS_ADDRESS:String = "rtmfp://p2p.rtmfp.net";
		    private static const CIRRUS_DEV_KEY:String = RTMFP::CIRRUS_KEY;
		
        /* The name of the "media" to pass between peers */
        private static const DATA:String = "data";
		
        /* Connection to the Cirrus rendezvous service */
        private var cirrus_conn:NetConnection;
		
		    /* ID of the peer to connect to */
		    private var peer_id:String;
		
		    /* Data streams to be established with peer */
		    private var send_stream:NetStream;
		    private var recv_stream:NetStream;
		    
		    private var notifiee:RTMFPRelayReactor;

        public function RTMFPRelay(notifiee:RTMFPRelayReactor)
        {   
          this.notifiee = notifiee;
          
          cirrus_conn = new NetConnection();
			    cirrus_conn.addEventListener(NetStatusEvent.NET_STATUS, notifiee.onNetStatusEvent);
			    cirrus_conn.addEventListener(IOErrorEvent.IO_ERROR, notifiee.onIOErrorEvent);
			    cirrus_conn.addEventListener(SecurityErrorEvent.SECURITY_ERROR, notifiee.onSecurityErrorEvent);
			
			    cirrus_conn.connect(CIRRUS_ADDRESS + "/" + CIRRUS_DEV_KEY);
        }

        public function get cirrus_id():String
        {
          if (cirrus_conn != null && cirrus_conn.connected) {
            return cirrus_conn.nearID;
          }
          
          return null;
        }
        
        public function get connected():Boolean
        {
          return (cirrus_conn != null && cirrus_conn.connected);
        }

        public function data_is(data:ByteArray):void
        {
          
          
        }
        
        public function get peer():String
        {
          return this.peer_id;
        }

        public function set peer(peer_id:String):void
        {
          if (peer_id == null) {
            throw new Error("Peer ID is null.")
    			} else if (peer_id == cirrus_conn.nearID) {
    				throw new Error("Peer ID cannot be the same as our ID.");
    			} else if (this.peer_id == peer_id) {
    			  throw new Error("Already connected to peer " + peer_id + ".");
    			} else if (this.recv_stream != null) {
            throw new Error("Cannot connect to a second peer.");
          }
          
          this.peer_id = peer_id;
          
          send_stream = new NetStream(cirrus_conn, NetStream.DIRECT_CONNECTIONS);
    			send_stream.addEventListener(NetStatusEvent.NET_STATUS, notifiee.onNetStatusEvent);
    			send_stream.publish(DATA);

    			recv_stream = new NetStream(cirrus_conn, peer_id);
    			recv_stream.addEventListener(NetStatusEvent.NET_STATUS, notifiee.onNetStatusEvent);
    			recv_stream.play(DATA);
        }
    }
}
