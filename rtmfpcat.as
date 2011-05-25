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

    import rtmfp.RTMFPSocket;
    import rtmfp.events.RTMFPSocketEvent;

    public class rtmfpcat extends Sprite
    {
        /* David's relay (nickname 3VXRyxz67OeRoqHn) that also serves a
           crossdomain policy. */
        private const DEFAULT_TOR_PROXY_ADDR:Object = {
            host: "173.255.221.44",
            port: 9001
        };
        /* Nate's facilitator -- also serving a crossdomain policy */
        private const DEFAULT_FACILITATOR_ADDR:Object = {
            host: "128.12.179.80",
            port: 9002
        };
        private const DEFAULT_TOR_CLIENT_ADDR:Object = {
            host: "127.0.0.1",
            port: 3333
        };

        // Milliseconds.
        private const FACILITATOR_POLL_INTERVAL:int = 10000;

        // Socket to facilitator.
        private var s_f:Socket;
        // Socket to RTMFP peer (flash proxy).
        private var s_r:RTMFPSocket;
        // Socket to local Tor client.
        private var s_t:Socket;

        /* TextField for debug output. */
        private var output_text:TextField;

        private var fac_addr:Object;
        private var tor_addr:Object;

        private var proxy_mode:Boolean;

        public function puts(s:String):void
        {
            output_text.appendText(s + "\n");
            output_text.scrollV = output_text.maxScrollV;
        }

        public function rtmfpcat()
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
                tor_addr = DEFAULT_TOR_CLIENT_ADDR;
            }

            main();
        }

        /* The main logic begins here, after start-up issues are taken care of. */
        private function main():void
        {
            establishRTMFPConnection();
        }

        private function establishRTMFPConnection():void
        {
            s_r = new RTMFPSocket();
            s_r.addEventListener(RTMFPSocketEvent.CONNECT_SUCCESS, function (e:Event):void {
                puts("Cirrus: connected with id " + s_r.id + ".");
                establishFacilitatorConnection();
            });
            s_r.addEventListener(RTMFPSocketEvent.CONNECT_FAIL, function (e:Event):void {
                puts("Error: failed to connect to Cirrus.");
            });
            s_r.addEventListener(RTMFPSocketEvent.PUBLISH_START, function(e:RTMFPSocketEvent):void {
                puts("Publishing started.");
            });
            s_r.addEventListener(RTMFPSocketEvent.PEER_CONNECTED, function(e:RTMFPSocketEvent):void {
                puts("Peer connected.");
            });
            s_r.addEventListener(RTMFPSocketEvent.PEER_DISCONNECTED, function(e:RTMFPSocketEvent):void {
                puts("Peer disconnected.");
            });
            s_r.addEventListener(RTMFPSocketEvent.PEERING_SUCCESS, function(e:RTMFPSocketEvent):void {
                puts("Peering success.");
                establishTorConnection();
            });
            s_r.addEventListener(RTMFPSocketEvent.PEERING_FAIL, function(e:RTMFPSocketEvent):void {
                puts("Peering fail.");
            });
            s_r.addEventListener(ProgressEvent.SOCKET_DATA, function (e:ProgressEvent):void {
                var bytes:ByteArray = new ByteArray();
                s_r.readBytes(bytes);
                puts("RTMFP: read " + bytes.length + " bytes.");
                s_t.writeBytes(bytes);
            });

            s_r.connect();
        }

        private function establishTorConnection():void
        {
            s_t = new Socket();
            s_t.addEventListener(Event.CONNECT, function (e:Event):void {
                puts("Tor: connected to " + tor_addr.host + ":" + tor_addr.port + ".");
            });
            s_t.addEventListener(Event.CLOSE, function (e:Event):void {
                puts("Tor: closed connection.");
            });
            s_t.addEventListener(IOErrorEvent.IO_ERROR, function (e:IOErrorEvent):void {
                puts("Tor: I/O error: " + e.text + ".");
            });
            s_t.addEventListener(ProgressEvent.SOCKET_DATA, function (e:ProgressEvent):void {
                var bytes:ByteArray = new ByteArray();
                s_t.readBytes(bytes, 0, e.bytesLoaded);
                puts("Tor: read " + bytes.length + " bytes.");
                s_r.writeBytes(bytes);
            });
            s_t.addEventListener(SecurityErrorEvent.SECURITY_ERROR, function (e:SecurityErrorEvent):void {
                puts("Tor: security error: " + e.text + ".");
            });

            s_t.connect(tor_addr.host, tor_addr.port);
        }

        private function establishFacilitatorConnection():void
        {
            s_f = new Socket();
            s_f.addEventListener(Event.CONNECT, function (e:Event):void {
                puts("Facilitator: connected to " + fac_addr.host + ":" + fac_addr.port + ".");
                if (proxy_mode) s_f.writeUTFBytes("GET / HTTP/1.0\r\n\r\n");
                else s_f.writeUTFBytes("POST / HTTP/1.0\r\n\r\nclient=" + s_r.id + "\r\n");
            });
            s_f.addEventListener(Event.CLOSE, function (e:Event):void {
                puts("Facilitator: connection closed.");
                if (proxy_mode) {
                    setTimeout(establishFacilitatorConnection, FACILITATOR_POLL_INTERVAL);
                }
            });
            s_f.addEventListener(IOErrorEvent.IO_ERROR, function (e:IOErrorEvent):void {
                puts("Facilitator: I/O error: " + e.text + ".");
            });
            s_f.addEventListener(ProgressEvent.SOCKET_DATA, function (e:ProgressEvent):void {
                var clientID:String = s_f.readMultiByte(e.bytesLoaded, "utf-8");
                puts("Facilitator: got \"" + clientID + "\"");
                if (clientID != "Registration list empty") {
                    puts("Connecting to " + clientID + ".");
                    s_r.peer = clientID;
                }
            });
            s_f.addEventListener(SecurityErrorEvent.SECURITY_ERROR, function (e:SecurityErrorEvent):void {
                puts("Facilitator: security error: " + e.text + ".");
            });

            s_f.connect(fac_addr.host, fac_addr.port);
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
