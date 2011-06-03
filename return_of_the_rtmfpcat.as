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
    import flash.utils.clearTimeout;
    import flash.utils.setTimeout;
    import flash.utils.clearInterval;
    import flash.utils.setInterval;
    import flash.utils.setTimeout;
    import flash.net.NetConnection;

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
        //private const DEFAULT_FACILITATOR_ADDR:Object = {
        //    host: "128.12.179.80",
        //    port: 9002
        //};

        /* David's facilitator. */
        private const DEFAULT_FACILITATOR_ADDR:Object = {
            host: "127.0.0.1",
            port: 9002
        };
       
        /* Cirrus server information. */
        private const DEFAULT_CIRRUS_ADDRESS:String = "rtmfp://p2p.rtmfp.net";
        private const DEFAULT_CIRRUS_KEY:String = RTMFP::CIRRUS_KEY;

        private static const DEFAULT_CIRCON_TIMEOUT:uint = 4000;

        private static const DEFAULT_PEER_CON_TIMEOUT:uint = 4000;

        /* Maximum connections. */
        private const DEFAULT_MAXIMUM_RCP_PAIRS:uint = 1;

        /* Milliseconds. */
        private const FACILITATOR_POLL_INTERVAL:int = 10000;

        private var max_rcp_pairs:uint;

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
        private var rcp_pairs_total:uint;

        private var rtmfp_data_counter:uint;

        /* Keep track of facilitator polling timer. */
        private var fac_poll_timeo_id:uint;

        /* Badge with a client counter */
        [Embed(source="badge.png")]
        private var BadgeImage:Class;
        private var tot_client_count_tf:TextField;
        private var tot_client_count_fmt:TextFormat;
        private var cur_client_count_tf:TextField;
        private var cur_client_count_fmt:TextFormat;

        /* Put a string to the screen. */
        public function puts(s:String):void
        {
            output_text.appendText(s + "\n");
            output_text.scrollV = output_text.maxScrollV;
        }
 
        public function update_client_count():void
        {
            /* Update total client count. */
            if (String(rcp_pairs_total).length == 1)
                tot_client_count_tf.text = "0" + String(rcp_pairs_total);
            else
                tot_client_count_tf.text = String(rcp_pairs_total);

            /* Update current client count. */
            cur_client_count_tf.text = "";
            for(var i:Number=0; i<rcp_pairs; i++)
                cur_client_count_tf.appendText(".");;
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
            
            /* Setup client counter for badge. */
            tot_client_count_fmt = new TextFormat();
            tot_client_count_fmt.color = 0xFFFFFF;
            tot_client_count_fmt.align = "center";
            tot_client_count_fmt.font = "courier-new";
            tot_client_count_fmt.bold = true;
            tot_client_count_fmt.size = 10;
            tot_client_count_tf = new TextField();
            tot_client_count_tf.width = 20;
            tot_client_count_tf.height = 17;
            tot_client_count_tf.background = false;
            tot_client_count_tf.defaultTextFormat = tot_client_count_fmt;
            tot_client_count_tf.x=47;
            tot_client_count_tf.y=0;

            cur_client_count_fmt = new TextFormat();
            cur_client_count_fmt.color = 0xFFFFFF;
            cur_client_count_fmt.align = "center";
            cur_client_count_fmt.font = "courier-new";
            cur_client_count_fmt.bold = true;
            cur_client_count_fmt.size = 10;
            cur_client_count_tf = new TextField();
            cur_client_count_tf.width = 20;
            cur_client_count_tf.height = 17;
            cur_client_count_tf.background = false;
            cur_client_count_tf.defaultTextFormat = cur_client_count_fmt;
            cur_client_count_tf.x=47;
            cur_client_count_tf.y=6;

            /* Update the client counter on badge. */
            update_client_count();

            /* Initialize connection pair count. */
            rcp_pairs = 0;

            /* Unique counter for RTMFP data publishing. */
            rtmfp_data_counter = 0;

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
            
            if(this.loaderInfo.parameters["debug"] != null)
                addChild(output_text);
            
            addChild(new BadgeImage());
            /* Tried unsuccessfully to add counter to badge. */
            /* For now, need two addChilds :( */
            addChild(tot_client_count_tf);
            addChild(cur_client_count_tf); 
            

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

            if(this.loaderInfo.parameters["max_con"])
                max_rcp_pairs = this.loaderInfo.parameters["max_con"];
            else
                max_rcp_pairs = DEFAULT_MAXIMUM_RCP_PAIRS;

            if(this.loaderInfo.parameters["start"])
                rtmfp_data_counter = this.loaderInfo.parameters["start"];

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
                   poll_for_id(); 
                } else {
                    puts("Setting up listening RTMFPConnectionPair");
                    var rcp:RTMFPConnectionPair = new RTMFPConnectionPair(circon, tor_addr, output_text);
                    rcp.addEventListener(Event.CONNECT, rcp_connect_event);
                    rcp.addEventListener(Event.CLOSE, rcp_close_event);
                    rcp.listen(String(rtmfp_data_counter));

                    var reg_str:String = circon.nearID + ":" + String(rtmfp_data_counter);
                    puts("Registering " + reg_str + " with facilitator");
                    register_id(reg_str, fac_addr);
                    rtmfp_data_counter++;
                }

                break;
            }
        }

        private function poll_for_id():void
        {
            puts("Facilitator: got " + rcp_pairs + " connections... polling for another");

            var s_f:Socket = new Socket();
            s_f.addEventListener(Event.CONNECT, function (e:Event):void {
                puts("Facilitator: connected to " + fac_addr.host + ":" + fac_addr.port + ".");
                s_f.writeUTFBytes("GET / HTTP/1.0\r\n\r\n");
            });
            s_f.addEventListener(Event.CLOSE, function (e:Event):void {
                puts("Facilitator: connection closed.");
            });
            s_f.addEventListener(IOErrorEvent.IO_ERROR, function (e:IOErrorEvent):void {
                puts("Facilitator: I/O error: " + e.text + ".");
            });
            s_f.addEventListener(ProgressEvent.SOCKET_DATA, function (e:ProgressEvent):void {
                var client:String = s_f.readMultiByte(e.bytesLoaded, "utf-8");
                puts("Facilitator: got \"" + client + "\"");
                if (client != "Registration list empty") {
                    puts("Connecting to " + client + ".");

                    var client_id:String = client.split(":")[0];
                    var client_data:String = client.split(":")[1];

                    clearTimeout(fac_poll_timeo_id);

                    var rcp:RTMFPConnectionPair = new RTMFPConnectionPair(circon, tor_addr, output_text);
                    rcp.addEventListener(Event.CONNECT, rcp_connect_event);
                    rcp.addEventListener(Event.UNLOAD, function (e:Event):void {
                        /* Failed to connect to peer... continue loop. */
                        puts("RTMFPConnectionPair: Timed out connecting to peer!");
                        if(rcp_pairs < max_rcp_pairs)
                            poll_for_id();
                    });
                    rcp.addEventListener(Event.CLOSE, rcp_close_event);
                    rcp.connect(client_id, client_data, DEFAULT_PEER_CON_TIMEOUT);
                } else {
                    /* Need to clear any outstanding timers to ensure
                     * that only one timer ever runs. */
                    clearTimeout(fac_poll_timeo_id);
                    if(rcp_pairs < max_rcp_pairs)
                        fac_poll_timeo_id = setTimeout(poll_for_id, FACILITATOR_POLL_INTERVAL); 
                }
            });
            s_f.addEventListener(SecurityErrorEvent.SECURITY_ERROR, function (e:SecurityErrorEvent):void {
                puts("Facilitator: security error: " + e.text + ".");
            });

            s_f.connect(fac_addr.host, fac_addr.port);
 
        }

        private function rcp_connect_event(e:Event):void
        {
            puts("RTMFPConnectionPair connected");

            rcp_pairs++;
            rcp_pairs_total++;

            /* Update the client count on the badge. */
            update_client_count();

            if(proxy_mode) {
                if(rcp_pairs < max_rcp_pairs) {
                    poll_for_id();
                }
            } else {
                /* Setup listening RTMFPConnectionPair. */
                if(rcp_pairs < max_rcp_pairs) {
                    puts("Setting up listening RTMFPConnectionPair");
                    var rcp:RTMFPConnectionPair = new RTMFPConnectionPair(circon, tor_addr, output_text);
                    rcp.addEventListener(Event.CONNECT, rcp_connect_event);
                    rcp.addEventListener(Event.CLOSE, rcp_close_event);
                    rcp.listen(String(rtmfp_data_counter));
                    var reg_str:String = circon.nearID + ":" + String(rtmfp_data_counter);
                    puts("Registering " + reg_str + " with facilitator");
                    register_id(reg_str, fac_addr);
                    rtmfp_data_counter++;
                }
            }
        }

        private function rcp_close_event(e:Event):void
        {
            puts("RTMFPConnectionPair closed");

            rcp_pairs--;

            /* Update the client count on the badge. */
            update_client_count();

            /* FIXME: Do I need to unregister the event listeners so
             * that the system can garbage collect the rcp object? */
            if(proxy_mode) {
                if(rcp_pairs < max_rcp_pairs) {
                    poll_for_id();
                }
            } else {
                if(rcp_pairs < max_rcp_pairs) {
                    puts("Setting up listening RTMFPConnectionPair");
                    var rcp:RTMFPConnectionPair = new RTMFPConnectionPair(circon, tor_addr, output_text);
                    rcp.addEventListener(Event.CONNECT, rcp_connect_event);
                    rcp.addEventListener(Event.CLOSE, rcp_close_event);
                    rcp.listen(String(rtmfp_data_counter));
                    var reg_str:String = circon.nearID + ":" + String(rtmfp_data_counter);
                    puts("Registering " + reg_str + " with facilitator");
                    register_id(reg_str, fac_addr);
                    rtmfp_data_counter++; 
                }
            }
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
    private var data:String;

    /* Connection to the Cirrus rendezvous service.
     * RTMFPSocket is established using this service. */
    private var circon:NetConnection;

    /* Unidirectional streams composing socket. */ 
    private var send_stream:NetStream;
    private var recv_stream:NetStream;

    /* Keeps the state of our connectedness. */
    public var connected:Boolean;

    private var connect_timeo_id:uint;

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

    public function listen(data:String):void
    {
        this.data = data;

        send_stream = new NetStream(circon, NetStream.DIRECT_CONNECTIONS);
        var client:Object = new Object();
        client.onPeerConnect = send_stream_peer_connect;
        send_stream.client = client;
        send_stream.publish(data); 
    }

    private function connect_timeout():void
    {
        puts("RTMFPSocket: Timed out connecting to peer");
        close();
        /* OK this is not so nice, because I wanted an Event.TIMEOUT event, but flash gives us none such event :( */
        dispatchEvent(new Event(Event.UNLOAD));
    }

    public function connect(clientID:String, data:String, timeout:uint):void
    {
        puts("RTMFPSocket: connecting to peer...");

        connect_timeo_id = setTimeout(connect_timeout, timeout);

        this.data = data;

        send_stream = new NetStream(circon, NetStream.DIRECT_CONNECTIONS);
        var client:Object = new Object();
        client.onPeerConnect = function (peer:NetStream):Boolean {
            clearTimeout(connect_timeo_id);
            puts("RTMFPSocket: connected to peer");
            connected = true;
            dispatchEvent(new Event(Event.CONNECT));
            peer.send("setPeerConnectAcknowledged");
            return true;
        };
        send_stream.client = client;
        send_stream.publish(data); 

        recv_stream = new NetStream(circon, clientID);
        var client_rtmfp:RTMFPSocketClient = new RTMFPSocketClient();
        client_rtmfp.addEventListener(ProgressEvent.SOCKET_DATA, function (event:ProgressEvent):void {
            dispatchEvent(event);
        }, false, 0, true);
        client_rtmfp.addEventListener(RTMFPSocketClient.PEER_CONNECT_ACKNOWLEDGED, function (event:Event):void {
            /* Empty... here for symmetry. */
        }, false, 0, true);
 
        recv_stream.client = client_rtmfp;
        recv_stream.play(data);
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
        recv_stream.play(data);

        peer.send("setPeerConnectAcknowledged");

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


    public function readBytes(bytes:ByteArray, offset:uint = 0, length:uint = 0):void
    {
        recv_stream.client.bytes.readBytes(bytes, offset, length);
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

[Event(name="peerConnectAcknowledged", type="flash.events.Event")]
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

    public function connect(clientID:String, rtmfp_data:String, timeout:uint):void
    {
        s_r = new RTMFPSocket(circon, output_text);
        s_r.addEventListener(Event.CONNECT, rtmfp_connect_event);
        s_r.addEventListener(Event.UNLOAD, function (e:Event):void {
            dispatchEvent(new Event(Event.UNLOAD));
        });
        s_r.addEventListener(ProgressEvent.SOCKET_DATA, function (e:ProgressEvent):void {
            /* It's possible that we receive data before we're connected
             * to the tor-side of the connection. In this case we want
             * to buffer the data. */
            if(!s_t.connected) {
                puts("MASSIVE ATTACK!");
            } else {
                var bytes:ByteArray = new ByteArray();
                s_r.readBytes(bytes, 0, e.bytesLoaded);
                puts("RTMFPConnectionPair: RTMFP: read " + bytes.length + " bytes.");
                s_t.writeBytes(bytes);                
            }
        });
        s_r.addEventListener(Event.CLOSE, rtmfp_close_event);
        s_r.connect(clientID, rtmfp_data, timeout);
    }

    public function listen(rtmfp_data:String):void
    {
        s_r = new RTMFPSocket(circon, output_text);
        s_r.addEventListener(Event.CONNECT, rtmfp_connect_event);
        s_r.addEventListener(ProgressEvent.SOCKET_DATA, function (e:ProgressEvent):void {
            /* It's possible that we receive data before we're connected
             * to the tor-side of the connection. In this case we want
             * to buffer the data. */
            if(!s_t.connected) {
                puts("MASSIVE ATTACK!");
            } else {
                var bytes:ByteArray = new ByteArray();
                s_r.readBytes(bytes, 0, e.bytesLoaded);
                puts("RTMFPConnectionPair: RTMFP: read " + bytes.length + " bytes.");
                s_t.writeBytes(bytes);                
            }
        });
 
        s_r.addEventListener(Event.CLOSE, rtmfp_close_event);
        s_r.listen(rtmfp_data);
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
        s_t.addEventListener(ProgressEvent.SOCKET_DATA, function (e:ProgressEvent):void {
            var bytes:ByteArray = new ByteArray();
            s_t.readBytes(bytes, 0, e.bytesLoaded);
            puts("RTMFPConnectionPair: Tor: read " + bytes.length + " bytes.");
            s_r.writeBytes(bytes);
        });
        s_t.addEventListener(IOErrorEvent.IO_ERROR, function (e:IOErrorEvent):void {
            puts("RTMFPConnectionPair: Tor: I/O error: " + e.text + ".");
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
