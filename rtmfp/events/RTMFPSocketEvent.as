package rtmfp.events
{
    import flash.events.Event;
    import flash.net.NetStream;

    public class RTMFPSocketEvent extends Event
    {
        public static const CONNECT_FAILED:String    = "connectFailed";
        public static const CONNECT_SUCCESS:String   = "connectSuccess";
        public static const CONNECT_CLOSED:String    = "connectClosed"
        public static const PEER_CONNECTED:String    = "peerConnected";
        public static const PEER_DISCONNECTED:String = "peerDisconnected";
        public static const PLAY_STARTED:String      = "playStarted";
        public static const PUBLISH_STARTED:String   = "publishStarted";
        public static const PUBLISH_FAILED:String    = "publishFailed";

        public var stream:NetStream;

        public function RTMFPSocketEvent(type:String, stream:NetStream = null, bubbles:Boolean = false, cancelable:Boolean = false)
        {
            super(type, bubbles, cancelable);
            this.stream = stream;
        }
    }
}
