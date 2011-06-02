/* CirrusSocket abstraction
 * ------------------------
 * Manages the NetConnection portion of RTMFP and also handles
 * the handshake between two Flash players to decide what their
 * data stream names will be.
 *
 * TODO: consider using farNonce/nearNonce instead of sending bytes?
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
    import flash.utils.clearInterval;
    import flash.utils.setInterval;
    
    import rtmfp.RTMFPSocket;
    import rtmfp.events.CirrusSocketEvent;
    import rtmfp.events.RTMFPSocketEvent;

    [Event(name=CirrusSocketEvent.CONNECT_CLOSED, type="com.flashproxy.rtmfp.events.CirrusSocketEvent")]
    [Event(name=CirrusSocketEvent.CONNECT_FAILED, type="com.flashproxy.rtmfp.events.CirrusSocketEvent")]
    [Event(name=CirrusSocketEvent.CONNECT_SUCCESS, type="com.flashproxy.rtmfp.events.CirrusSocketEvent")]
    [Event(name=CirrusSocketEvent.HELLO_RECEIVED, type="com.flashproxy.rtmfp.events.CirrusSocketEvent")]
    public class CirrusSocket extends EventDispatcher
    {
        private static const CONNECT_TIMEOUT:uint = 4000; // in milliseconds
		
        /* We'll append a unique number to the DATA_STREAM_PREFIX for each
           new stream we create so that we have unique streams per player. */
        private static const DATA_STREAM_PREFIX:String = "DATA";   
        private var data_stream_suffix:uint = 0;

        /* Connection to the Cirrus rendezvous service */
        public var connection:NetConnection;

        /* Timeouts */
        private var connect_timeout:int;
        private var hello_timeout:int;

        public function CirrusSocket()
        {
            connection = new NetConnection();
            connection.addEventListener(NetStatusEvent.NET_STATUS, on_net_status_event);
            connection.addEventListener(IOErrorEvent.IO_ERROR, on_io_error_event);
            connection.addEventListener(SecurityErrorEvent.SECURITY_ERROR, on_security_error_event);
            
            /* Set up a client object to handle the hello callback */
            var client:Object = new Object();
            client.onRelay = on_hello;
            connection.client = client;
        }

        public function connect(addr:String, key:String):void
        {
            if (!this.connected) {
                connect_timeout = setInterval(fail, CONNECT_TIMEOUT);
                connection.connect(addr, key);
            } else {
                throw new Error("Cannot connect Cirrus socket: already connected.");
            }
        }

        public function close():void
        {
            if (this.connected) {
                connection.close();
            } else {
                throw new Error("Cannot close Cirrus socket: not connected.");
            }
        }

        public function get connected():Boolean
        {
            return (connection != null && connection.connected);
        }
        
        public function get id():String
        {
            if (this.connected) {
                return connection.nearID;
            }

            return null;
        }
        
        public function get local_stream_name():String
        {
            return DATA_STREAM_PREFIX + data_stream_suffix;
        }

	/* Sends a hello message to the Flash player with Cirrus ID "id" 
	   We use this new call protocol outlined here:
	   http://forums.adobe.com/thread/780788?tstart=0 */
	public function send_hello(id:String):void
        {
            if (this.connected) {
                connection.call("relay", null, id, local_stream_name);
            } else {
                throw new Error("Cannot send hello: Cirrus socket not connected.");
            }
        }

/*************************** PRIVATE HELPER FUNCTIONS *************************/		

        private function fail():void
        {
            clearInterval(connect_timeout);
            dispatchEvent(new CirrusSocketEvent(CirrusSocketEvent.CONNECT_FAILED));
        }

        private function on_hello(peer:String, ...args):void
        {
            var stream:String = args[0];
            dispatchEvent(new CirrusSocketEvent(CirrusSocketEvent.HELLO_RECEIVED, peer, stream));
            data_stream_suffix++;
        }

        private function on_io_error_event(event:IOErrorEvent):void
        {
            fail();
        }

        private function on_net_status_event(event:NetStatusEvent):void
        {
            if (event.info.code == "NetConnection.Connect.Success") {
              	clearInterval(connect_timeout);
              	dispatchEvent(new CirrusSocketEvent(CirrusSocketEvent.CONNECT_SUCCESS));
            }
        }

        private function on_security_error_event(event:SecurityErrorEvent):void
        {
            fail();
        }
    }
}
