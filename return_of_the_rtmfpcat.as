/* Meow! */
package
{
    import flash.display.Sprite;
    import flash.display.StageAlign;
    import flash.display.StageScaleMode;
    import flash.text.TextField;
    import flash.text.TextFormat;
    import flash.net.Socket;
    import flash.events.Event;
    import flash.events.EventDispatcher;
    import flash.events.IOErrorEvent;
    import flash.events.NetStatusEvent;
    import flash.events.ProgressEvent;
    import flash.events.SecurityErrorEvent;
    import flash.utils.ByteArray;
    import flash.utils.setTimeout;
    import flash.utils.clearInterval;
    import flash.utils.setInterval;
    import flash.utils.setTimeout;
    import flash.net.NetConnection;

    import rtmfp.RTMFPSocket;
    import rtmfp.events.RTMFPSocketEvent;

    public class return_of_the_rtmfpcat extends Sprite
    {
        /* David's relay (nickname 3VXRyxz67OeRoqHn) that also serves a
           crossdomain policy. */
        private const DEFAULT_TOR_PROXY_ADDR:Object = {
            host: "173.255.221.44",
            port: 9001
        };

        /* Tor application running on the client. */
        private const DEFAULT_TOR_CLIENT_ADDR:Object = {
            host: "127.0.0.1",
            port: 3333
        };

        /* Nate's facilitator -- also serving a crossdomain policy */
        private const DEFAULT_FACILITATOR_ADDR:Object = {
            host: "128.12.179.80",
            port: 9002
        };
       
        /* Cirrus server information. */
        private const DEFAULT_CIRRUS_ADDRESS:String = "rtmfp://p2p.rtmfp.net";
        private const DEFAULT_CIRRUS_KEY:String = RTMFP::CIRRUS_KEY;

        private static const DEFAULT_CIRCON_TIMEOUT:uint = 4000;

        /* TextField for debug output. */
        private var output_text:TextField;

        /* Are we the proxy or the client? */
        private var proxy_mode:Boolean;
       
        /* Facilitator address */
        private var fac_addr:Object;

        /* Tor address. If we're a proxy, then this address is a relay.
         * If we're running on the client, then this address is the Tor
         * client application. */
        private var tor_addr:Object;

        /* Cirrus address */
        private var cir_addr:String;

        /* Cirrus key */
        private var cir_key:String;

        /* Connection to the Cirrus rendezvous service */
        private var circon:NetConnection;

        /* Cirrus connection timeout ID. */
        private var circon_timeo_id:int;

        /* Array of connection pairs */
        private var con_pairs:Array;

        /* Put a string to the screen. */
        public function puts(s:String):void
        {
            output_text.appendText(s + "\n");
            output_text.scrollV = output_text.maxScrollV;
        }
        
        public function return_of_the_rtmfpcat()
        {
            // Absolute positioning.
            stage.scaleMode = StageScaleMode.NO_SCALE;
            stage.align = StageAlign.TOP_LEFT;

            output_text = new TextField();
            output_text.width = stage.stageWidth;
            output_text.height = stage.stageHeight;
            output_text.background = true;
            output_text.backgroundColor = 0x001f0f;
            output_text.textColor = 0x44cc44;

            puts("Meow!");
            puts("Starting.");
            // Wait until the query string parameters are loaded.
            this.loaderInfo.addEventListener(Event.COMPLETE, loaderinfo_complete);
        }

        private function loaderinfo_complete(e:Event):void
        {
            var fac_spec:String;
            var tor_spec:String;

            puts("Parameters loaded.");

            proxy_mode = (this.loaderInfo.parameters["proxy"] != null);
            addChild(output_text);

            fac_spec = this.loaderInfo.parameters["facilitator"];
            if (fac_spec) {
                puts("Facilitator spec: \"" + fac_spec + "\"");
                fac_addr = parse_addr_spec(fac_spec);
                if (!fac_addr) {
                    puts("Error: Facilitator spec must be in the form \"host:port\".");
                    return;
                }
            } else {
                fac_addr = DEFAULT_FACILITATOR_ADDR;
            }

            tor_spec = this.loaderInfo.parameters["tor"];
            if (tor_spec) {
                puts("Tor spec: \"" + tor_spec + "\"");
                tor_addr = parse_addr_spec(tor_spec);
                if (!tor_addr) {
                    puts("Error: Tor spec must be in the form \"host:port\".");
                    return;
                }
            } else {
                if (proxy_mode)
                    tor_addr = DEFAULT_TOR_PROXY_ADDR;
                else
                    tor_addr = DEFAULT_TOR_CLIENT_ADDR;
            }

            if(this.loaderInfo.parameters["cirrus_server"])
                cir_addr = this.loaderInfo.parameters["cirrus_server"];
            else
                cir_addr = DEFAULT_CIRRUS_ADDRESS;

            if(this.loaderInfo.parameters["cirrus_key"])
                cir_key = this.loaderInfo.parameters["cirrus_key"];      
            else
                cir_key = DEFAULT_CIRRUS_KEY;

            main();
        }

        /* The main logic begins here, after start-up issues are taken care of. */
        private function main():void
        {
            puts("Making connection to cirrus server.");
            circon = new NetConnection();
            circon.addEventListener(NetStatusEvent.NET_STATUS, circon_netstatus_event);
            circon.addEventListener(IOErrorEvent.IO_ERROR, function (e:Event):void { 
                puts("Cirrus connection had an IOErrorEvent.IO_ERROR event");
            });
            circon.addEventListener(SecurityErrorEvent.SECURITY_ERROR, function (e:Event):void {
                puts("Cirrus connection had a SecurityErrorEvent.SECURITY_ERROR");
            });
            circon.connect(cir_addr + "/" + cir_key);
            circon_timeo_id = setInterval(circon_timeout, DEFAULT_CIRCON_TIMEOUT);
        }

        private function circon_netstatus_event(event:NetStatusEvent):void
        {
            switch (event.info.code) {
            case "NetConnection.Connect.Success" :
                puts("circon_netstatus_event: NetConnection.Connect.Success");
                puts("Got id " + circon.nearID + ".");
                clearInterval(circon_timeo_id);
                
                if(proxy_mode) {

                } else {
                    /* Listen for incoming RTMFP connections. */
                    var s_r:RTMFPSocket = new RTMFPSocket(circon);
                    s_r.addEventListener(Event.CONNECT, rtmfp_connect_event);
                    s_r.listen();

                    /* Register ID with facilitator. */
                    register_id(circon.nearID, fac_addr);
                }

                break;
            case "NetStream.Connect.Success" :
                puts("circon_netstatus_event: NetStream.Connect.Success");  
                break;
            case "NetStream.Publish.BadName" :
                puts("circon_netstatus_event: NetStream.Publish.BadName");
                break;
            case "NetStream.Connect.Closed" :
                puts("circon_netstatus_event: NetStream.Connect.Closed");
                // we've disconnected from the peer
                // can reset to accept another
                // clear the publish stream and re-publish another
                break;
            }
        }

        private function rtmfp_connect_event(e:Event):void
        {
           puts("VICTORY!"); 
        }

        private function register_id(id:String, fac_addr:Object):void
        {
            var s_f:Socket = new Socket();
            s_f.addEventListener(Event.CONNECT, function (e:Event):void {
                puts("Facilitator: connected to " + fac_addr.host + ":" + fac_addr.port + ".");
                puts("Registering id " + id);
                s_f.writeUTFBytes("POST / HTTP/1.0\r\n\r\nclient=" + id + "\r\n");
            });
            s_f.addEventListener(Event.CLOSE, function (e:Event):void {
                puts("Facilitator: connection closed.");
            });
            s_f.addEventListener(IOErrorEvent.IO_ERROR, function (e:IOErrorEvent):void {
                puts("Facilitator: I/O error: " + e.text + ".");
            });
            s_f.addEventListener(SecurityErrorEvent.SECURITY_ERROR, function (e:SecurityErrorEvent):void {
                puts("Facilitator: security error: " + e.text + ".");
            });

            s_f.connect(fac_addr.host, fac_addr.port); 
        }

        private function circon_timeout():void
        {
            puts("Cirrus server connection timed out!");
        }

        /* Parse an address in the form "host:port". Returns an Object with
           keys "host" (String) and "port" (int). Returns null on error. */
        private static function parse_addr_spec(spec:String):Object
        {
            var parts:Array;
            var addr:Object;

            parts = spec.split(":", 2);
            if (parts.length != 2 || !parseInt(parts[1]))
                return null;
            addr = {}
            addr.host = parts[0];
            addr.port = parseInt(parts[1]);

            return addr;
        }
    }
}

import flash.display.Sprite;
import flash.events.Event;
import flash.events.EventDispatcher;
import flash.events.IOErrorEvent;
import flash.events.ProgressEvent;
import flash.events.SecurityErrorEvent;
import flash.net.Socket;
import flash.utils.ByteArray;
import flash.utils.clearTimeout;
import flash.utils.getTimer;
import flash.utils.setTimeout;
import flash.net.NetConnection;
import flash.net.NetStream;

class RTMFPSocket extends EventDispatcher
{
    /* The name of the "media" to pass between peers. */
    private static const DATA:String = "data";

    /* Connection to the Cirrus rendezvous service.
     * RTMFPSocket is established using this service. */
    private var circon:NetConnection;

    /* Unidirectional streams composing socket. */ 
    private var send_stream:NetStream;
    private var recv_stream:NetStream;

    public function RTMFPSocket(circon:NetConnection)
    {
        this.circon = circon;
    }

    public function listen():void
    {
        send_stream = new NetStream(circon, NetStream.DIRECT_CONNECTIONS);
        var client:Object = new Object();
        client.onPeerConnect = send_stream_peer_connect;
        send_stream.client = client;
        send_stream.publish(DATA); 
    }

    private function send_stream_peer_connect(peer:NetStream):Boolean
    {
        recv_stream = new NetStream(circon, peer.farID);
        var client:RTMFPSocketClient = new RTMFPSocketClient();
        client.addEventListener(ProgressEvent.SOCKET_DATA, function (event:ProgressEvent):void {
            dispatchEvent(event);
        }, false, 0, true);
        client.addEventListener(RTMFPSocketClient.PEER_CONNECT_ACKNOWLEDGED, function (event:Event):void {
            dispatchEvent(new Event(Event.CONNECT));
        }, false, 0, true);
        recv_stream.client = client;
        recv_stream.play(DATA);

        return true;
    }


}

dynamic class RTMFPSocketClient extends EventDispatcher
{
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

class ConnectionPair extends EventDispatcher
{

}
