/*
The RTMFPSocket class provides a socket-like interface around RTMFP
NetConnection and NetStream. Each RTMFPSocket contains one NetConnection and two
NetStreams, one for reading and one for writing.

To create a listening socket:
    var rs:RTMFPSocket = new RTMFPSocket(url, key);
    rs.addEventListener(Event.COMPLETE, function (e:Event):void {
        // rs.id is set and can be sent out of band to the client.
    });
    rs.addEventListener(RTMFPSocket.ACCEPT_EVENT, function (e:Event):void {
        // rs.peer_id is the ID of the connected client.
    });
    rs.listen();
To connect to a listening socket:
    // Receive peer_id out of band.
    var rs:RTMFPSocket = new RTMFPSocket(url, key);
    rs.addEventListener(Event.CONNECT, function (e:Event):void {
        // rs.id and rs.peer_id are now set.
    });
*/

package
{
    import flash.events.Event;
    import flash.events.EventDispatcher;
    import flash.events.IOErrorEvent;
    import flash.events.NetStatusEvent;
    import flash.events.ProgressEvent;
    import flash.net.NetConnection;
    import flash.net.NetStream;
    import flash.utils.ByteArray;

    public class RTMFPSocket extends EventDispatcher
    {
        public static const ACCEPT_EVENT:String = "accept";

        public var connected:Boolean;

        private var nc:NetConnection;
        private var incoming:NetStream;
        private var outgoing:NetStream;

        /* Cache to hold the peer ID between when connect is called and the
           NetConnection exists. */
        private var connect_peer_id:String;

        private var buffer:ByteArray;

        private var cirrus_url:String;
        private var cirrus_key:String;

        public function RTMFPSocket(cirrus_url:String, cirrus_key:String = "")
        {
            connected = false;

            buffer = new ByteArray();

            this.cirrus_url = cirrus_url;
            this.cirrus_key = cirrus_key;

            nc = new NetConnection();
        }

        public function get id():String
        {
            return nc.nearID;
        }

        public function get peer_id():String
        {
            return incoming.farID;
        }

        /* NetStatusEvents that aren't handled more specifically in
           listen_netstatus_event or connect_netstatus_event. */
        private function generic_netstatus_event(e:NetStatusEvent):void
        {
            switch (e.info.code) {
            case "NetConnection.Connect.Closed":
                connected = false;
                dispatchEvent(new Event(Event.CLOSE));
                break;
            case "NetStream.Connect.Closed":
                connected = false;
                close();
                break;
            default:
                var event:IOErrorEvent = new IOErrorEvent(IOErrorEvent.IO_ERROR);
                event.text = e.info.code;
                dispatchEvent(event);
                break;
            }
        }

        private function listen_netstatus_event(e:NetStatusEvent):void
        {
            switch (e.info.code) {
            case "NetConnection.Connect.Success":
                outgoing = new NetStream(nc, NetStream.DIRECT_CONNECTIONS);
                outgoing.client = {
                    onPeerConnect: listen_onpeerconnect
                };
                outgoing.publish("server");

                /* listen is complete, ready to accept. */
                dispatchEvent(new Event(Event.COMPLETE));
                break;
            case "NetStream.Connect.Success":
                break;
            default:
                return generic_netstatus_event(e);
                break;
            }
        }

        private function listen_onpeerconnect(peer:NetStream):Boolean {
            incoming = new NetStream(nc, peer.farID);
            incoming.client = {
                r: receive_data
            };
            incoming.play("client");

            connected = true;
            dispatchEvent(new Event(ACCEPT_EVENT));

            return true;
        }

        private function connect_netstatus_event(e:NetStatusEvent):void
        {
            switch (e.info.code) {
            case "NetConnection.Connect.Success":
                outgoing = new NetStream(nc, NetStream.DIRECT_CONNECTIONS);
                outgoing.publish("client");

                incoming = new NetStream(nc, connect_peer_id);
                incoming.client = {
                    r: receive_data
                };
                incoming.play("server");
                break;
            case "NetStream.Connect.Success":
                connected = true;
                dispatchEvent(new Event(Event.CONNECT));
                break;
            default:
                return generic_netstatus_event(e);
                break;
            }
        }

        /* Function called back when the other side does a send. */
        private function receive_data(bytes:ByteArray):void {
            var event:ProgressEvent;

            event = new ProgressEvent(ProgressEvent.SOCKET_DATA);
            event.bytesLoaded = bytes.bytesAvailable;

            bytes.readBytes(buffer, buffer.length, bytes.bytesAvailable);

            dispatchEvent(event);
        }

        public function listen():void
        {
            nc.addEventListener(NetStatusEvent.NET_STATUS, listen_netstatus_event);
            nc.connect(cirrus_url, cirrus_key);
        }

        public function connect(peer_id:String):void
        {
            /* Store for later reading by connect_netstatus_event. */
            this.connect_peer_id = peer_id;

            nc.addEventListener(NetStatusEvent.NET_STATUS, connect_netstatus_event);
            nc.connect(cirrus_url, cirrus_key);
        }

        public function close():void
        {
            if (outgoing)
                outgoing.close();
            if (incoming)
                incoming.close();
            if (nc)
                nc.close();
        }

        public function readBytes(output:ByteArray, offset:uint = 0, length:uint = 0):void
        {
            buffer.readBytes(output, offset, length);
            if (buffer.bytesAvailable == 0) {
                /* Reclaim memory space. */
                buffer.clear();
            }
        }

        public function writeBytes(input:ByteArray, offset:uint = 0, length:uint = 0):void
        {
            var sendbuf:ByteArray;

            /* Read into a new buffer, in case offset and length do not
               completely span input. */
            sendbuf = new ByteArray();
            sendbuf.writeBytes(input, offset, length);

            /* Use a short method name because it's sent over the wire. */
            outgoing.send("r", sendbuf);
        }

        public function flush():void
        {
            /* Ignored. */
        }
    }
}
