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

        /* David's facilitator. */
        //private const DEFAULT_FACILITATOR_ADDR:Object = {
        //    host: "tor-facilitator.bamsoftware.com",
        //    port: 9006
        //};
       
        /* Cirrus server information. */
        private const DEFAULT_CIRRUS_ADDRESS:String = "rtmfp://p2p.rtmfp.net";
        private const DEFAULT_CIRRUS_KEY:String = RTMFP::CIRRUS_KEY;

        private static const DEFAULT_CIRCON_TIMEOUT:uint = 4000;

        /* Maximum connections. */
        private const MAXIMUM_RCP_PAIRS:uint = 1;

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

        /* Number of connected RTMFPConnectionPairs. */
        private var rcp_pairs:uint;

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

            /* Initialize connection pair count. */
            rcp_pairs = 0;

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
                puts("Cirrus server connection established.");
                puts("Got id " + circon.nearID + ".");
                clearInterval(circon_timeo_id);
                
                if(proxy_mode) {

                } else {
                    puts("Setting up listening RTMFPConnectionPair");
                    var rcp:RTMFPConnectionPair = new RTMFPConnectionPair(circon, tor_addr, output_text);
                    rcp.addEventListener(Event.CONNECT, rcp_connect_event);
                    rcp.addEventListener(Event.CLOSE, rcp_close_event);
                    rcp.listen();

                    puts("Registering with facilitator");
                    /* Register ID with facilitator. */
                    register_id(circon.nearID, fac_addr);
                }

                break;
            }
        }

        private function rcp_connect_event(e:Event):void
        {
            puts("RTMFPConnectionPair connected");

            rcp_pairs++;

            if(proxy_mode) {

            } else {
                /* Setup listening RTMFPConnectionPair. */
                if(rcp_pairs < MAXIMUM_RCP_PAIRS) {
                    puts("Setting up listening RTMFPConnectionPair");
                    var rcp:RTMFPConnectionPair = new RTMFPConnectionPair(circon, tor_addr, output_text);
                    rcp.addEventListener(Event.CONNECT, rcp_connect_event);
                    rcp.addEventListener(Event.CLOSE, rcp_close_event);
                    rcp.listen();
                }
            }
        }

        private function rcp_close_event(e:Event):void
        {
            puts("RTMFPConnectionPair closed");

            rcp_pairs--;

            /* FIXME: Do I need to unregister the event listeners so
             * that the system can garbage collect the rcp object? */
        }

        private function register_id(id:String, fac_addr:Object):void
        {
            var s_f:Socket = new Socket();
            s_f.addEventListener(Event.CONNECT, function (e:Event):void {
                puts("Facilitator: connected to " + fac_addr.host + ":" + fac_addr.port + ".");
                puts("Facilitator: Registering id " + id);
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
import flash.events.NetStatusEvent;
import flash.net.Socket;
import flash.utils.ByteArray;
import flash.utils.clearTimeout;
import flash.utils.getTimer;
import flash.utils.setTimeout;
import flash.net.NetConnection;
import flash.net.NetStream;
import flash.text.TextField;

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

    /* Keeps the state of our connectedness. */
    public var connected:Boolean;

    private var output_text:TextField;

    /* Put a string to the screen. */
    public function puts(s:String):void
    {
        output_text.appendText(s + "\n");
        output_text.scrollV = output_text.maxScrollV;
    }
 
    public function RTMFPSocket(circon:NetConnection, output_text:TextField)
    {
        this.circon = circon;
        this.output_text = output_text;
        connected = false;
        
        circon.addEventListener(NetStatusEvent.NET_STATUS, circon_netstatus_event);
        circon.addEventListener(IOErrorEvent.IO_ERROR, function (e:Event):void { 
            puts("RTMFPSocket: Cirrus connection had an IOErrorEvent.IO_ERROR event");
        });
        circon.addEventListener(SecurityErrorEvent.SECURITY_ERROR, function (e:Event):void {
            puts("RTMFPSocket: Cirrus connection had a SecurityErrorEvent.SECURITY_ERROR");
        });
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
        puts("RTMFPSocket: peer connecting...");
        recv_stream = new NetStream(circon, peer.farID);
        var client:RTMFPSocketClient = new RTMFPSocketClient();
        client.addEventListener(ProgressEvent.SOCKET_DATA, function (event:ProgressEvent):void {
            dispatchEvent(event);
        }, false, 0, true);
        client.addEventListener(RTMFPSocketClient.PEER_CONNECT_ACKNOWLEDGED, function (event:Event):void {
            puts("RTMFPSocket: peer connected");
            connected = true;
            dispatchEvent(new Event(Event.CONNECT));
        }, false, 0, true);
        recv_stream.client = client;
        recv_stream.play(DATA);

        return true;
    }

    private function circon_netstatus_event(event:NetStatusEvent):void
    {
        switch (event.info.code) {
        case "NetStream.Connect.Closed" :
            puts("RTMFPSocket: NetStream connection was closed");

            if(connected)
            {
                send_stream.close();
                recv_stream.close();
                connected = false;
                dispatchEvent(new Event(Event.CLOSE));
            }

            break;
        }
    }


    public function readBytes(bytes:ByteArray):void
    {
        recv_stream.client.bytes.readBytes(bytes);
    }

    public function writeBytes(bytes:ByteArray):void
    {
        send_stream.send("dataAvailable", bytes);
    }

    public function close():void
    {
        puts("RTMFPSocket: closing...");
        send_stream.close();
        recv_stream.close();
        connected = false;
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

class RTMFPConnectionPair extends EventDispatcher
{
    private var circon:NetConnection;

    private var tor_addr:Object;

    private var s_r:RTMFPSocket;

    private var s_t:Socket;

    private var output_text:TextField;

    /* Put a string to the screen. */
    public function puts(s:String):void
    {
        output_text.appendText(s + "\n");
        output_text.scrollV = output_text.maxScrollV;
    }
 
    public function RTMFPConnectionPair(circon:NetConnection, tor_addr:Object, output_text:TextField)
    {
        this.circon = circon;
        this.tor_addr = tor_addr;
        this.output_text = output_text;
    }

    public function listen():void
    {
        s_r = new RTMFPSocket(circon, output_text);
        s_r.addEventListener(Event.CONNECT, rtmfp_connect_event);
        s_r.addEventListener(Event.CLOSE, rtmfp_close_event);
        s_r.listen();
    }

    private function rtmfp_connect_event(e:Event):void
    {
        puts("RTMFPConnectionPair: RTMFPSocket side connected!");
        puts("RTMFPConnectionPair: setting up tor side connection...");

        /* Setup tor connection linked to RTMFPSocket. */
        s_t = new Socket();
        s_t.addEventListener(Event.CONNECT, function (e:Event):void {
            puts("RTMFPConnectionPair: Tor: connected to " + tor_addr.host + ":" + tor_addr.port + ".");
            dispatchEvent(new Event(Event.CONNECT));
        });
        s_t.addEventListener(Event.CLOSE, function (e:Event):void {
            puts("RTMFPConnectionPair: Tor: closed connection.");
            /* Close other side of connection pair if it is open and
             * dispatch close event. */
            if(s_r.connected)
                s_r.close();
            dispatchEvent(new Event(Event.CLOSE));
        });
        s_t.addEventListener(IOErrorEvent.IO_ERROR, function (e:IOErrorEvent):void {
            puts("RTMFPConnectionPair: Tor: I/O error: " + e.text + ".");
        });
        s_t.addEventListener(ProgressEvent.SOCKET_DATA, function (e:ProgressEvent):void {
            var bytes:ByteArray = new ByteArray();
            s_t.readBytes(bytes, 0, e.bytesLoaded);
            puts("RTMFPConnectionPair: Tor: read " + bytes.length + " bytes.");
            s_r.writeBytes(bytes);
        });
        s_t.addEventListener(SecurityErrorEvent.SECURITY_ERROR, function (e:SecurityErrorEvent):void {
            puts("RTMFPConnectionPair: Tor: security error: " + e.text + ".");
        });

        s_t.connect(tor_addr.host, tor_addr.port);
    }

    private function rtmfp_close_event(e:Event):void
    {
       puts("RTMFPConnectionPair: RTMFPSocket closed connection"); 
       /* Close other side of connection pair if it is open and dispatch
        * close event. */
       if(s_t.connected)
           s_t.close();
       dispatchEvent(new Event(Event.CLOSE)); 
    }

}
