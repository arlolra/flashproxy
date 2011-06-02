package rtmfp
{
    import flash.events.Event;
    import flash.events.EventDispatcher;
    import flash.events.ProgressEvent;
    import flash.utils.ByteArray;

    [Event(name=RTMFPSocketClient.CONNECT_ACKNOWLEDGED, type="flash.events.Event")]
    public dynamic class RTMFPSocketClient extends EventDispatcher {
        public static const DATA_AVAILABLE:String = "data_available";
        public static const CONNECT_ACKNOWLEDGED:String = "connectAcknowledged";
        public static const SET_CONNECT_ACKNOWLEDGED:String = "set_connect_acknowledged";

        private var _bytes:ByteArray;
        private var _connect_acknowledged:Boolean;

        public function RTMFPSocketClient()
        {
            super();
            _bytes = new ByteArray();
            _connect_acknowledged = false;
        }

        public function get bytes():ByteArray
        {
            return _bytes;
        }

        public function data_available(bytes:ByteArray):void
        {
            bytes.readBytes(_bytes, _bytes.length, 0);
            dispatchEvent(new ProgressEvent(ProgressEvent.SOCKET_DATA, false, false, _bytes.bytesAvailable, _bytes.bytesAvailable));
        }

        public function get connect_acknowledged():Boolean
        {
            return _connect_acknowledged;
        }

        public function set_connect_acknowledged():void
        {
            _connect_acknowledged = true;
            dispatchEvent(new Event(CONNECT_ACKNOWLEDGED));
        }
    }
}
