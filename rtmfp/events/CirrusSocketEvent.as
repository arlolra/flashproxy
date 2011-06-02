package rtmfp.events
{
    import flash.events.Event;

    public class CirrusSocketEvent extends Event
    {
        public static const CONNECT_CLOSED:String  = "connectClosed";
        public static const CONNECT_FAILED:String  = "connectFailed";
        public static const CONNECT_SUCCESS:String = "connectSuccess";
        public static const HELLO_RECEIVED:String  = "helloReceived";

        public var peer:String;
        public var stream:String;

        public function CirrusSocketEvent(type:String, peer:String = null, stream:String = null, bubbles:Boolean = false, cancelable:Boolean = false)
        {
            super(type, bubbles, cancelable);
            this.peer = peer;
            this.stream = stream;
        }
    }
}
