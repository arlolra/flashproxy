package rtmfp
{
	import flash.events.Event;
	import flash.events.EventDispatcher;
	import flash.events.ProgressEvent;
	import flash.utils.ByteArray;

	[Event(name="peerConnectAcknowledged", type="flash.events.Event")]
	public dynamic class RTMFPSocketClient extends EventDispatcher {
		public static const PEER_CONNECT_ACKNOWLEDGED:String = "peerConnectAcknowledged";
		
		private var _bytes:ByteArray;
		private var _peerID:String;
		private var _peerConnectAcknowledged:Boolean;
		
		public function RTMFPSocketClient()
		{
			super();
			_bytes = new ByteArray();
			_peerID = null;
			_peerConnectAcknowledged = false;
		}
		
		public function get bytes():ByteArray
		{
		  return _bytes;
		}
		
		public function dataAvailable(bytes:ByteArray):void
		{
		  this._bytes.clear();
		  bytes.readBytes(this._bytes);
		  dispatchEvent(new ProgressEvent(ProgressEvent.SOCKET_DATA, false, false, this._bytes.bytesAvailable, this._bytes.length));
		}
		
		public function get peerConnectAcknowledged():Boolean
		{
		  return _peerConnectAcknowledged;
		}
		
		public function setPeerConnectAcknowledged():void
		{
			_peerConnectAcknowledged = true;
			dispatchEvent(new Event(PEER_CONNECT_ACKNOWLEDGED));
		}
		
		public function get peerID():String
		{
		  return _peerID;
		}
		
		public function set peerID(id:String):void
		{
		  _peerID = id;
		}
	}
}