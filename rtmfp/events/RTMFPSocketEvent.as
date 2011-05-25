package rtmfp.events
{
    import flash.events.Event;
    import flash.net.NetStream;

    public class RTMFPSocketEvent extends Event
    {
        public static const CONNECT_SUCCESS:String   = "connectSuccess";
        public static const CONNECT_FAIL:String      = "connectFail";
        public static const PUBLISH_START:String     = "publishStart";
        public static const PEER_CONNECTED:String    = "peerConnected";
        public static const PEER_DISCONNECTED:String = "peerDisconnected";
        public static const PEERING_SUCCESS:String   = "peeringSuccess";
        public static const PEERING_FAIL:String      = "peeringFail";

        public var stream:NetStream;

        public function RTMFPSocketEvent(type:String, streamVal:NetStream = null, bubbles:Boolean = false, cancelable:Boolean = false)
        {
            super(type, bubbles, cancelable);
            stream = streamVal;
        }
    }
}
