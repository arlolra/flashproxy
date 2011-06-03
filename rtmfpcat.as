package
{
    import flash.display.Sprite;
    import flash.display.StageAlign;
    import flash.display.StageScaleMode;
    import flash.text.TextField;
    import flash.text.TextFormat;
    import flash.events.Event;
    import flash.utils.setTimeout;

    import rtmfp.CirrusSocket;
    import rtmfp.FacilitatorSocket;
    import rtmfp.ProxyPair;
    import rtmfp.events.CirrusSocketEvent;
    import rtmfp.events.FacilitatorSocketEvent;

    public class rtmfpcat extends Sprite
    {
        /* Adobe's Cirrus server and Nate's key */
        private const DEFAULT_CIRRUS_ADDR:String = "rtmfp://p2p.rtmfp.net";
        private const DEFAULT_CIRRUS_KEY:String = RTMFP::CIRRUS_KEY;
        
        /* Nate's facilitator -- serves a crossdomain policy */
        private const DEFAULT_FACILITATOR_ADDR:Object = {
            host: "128.12.179.80",
            port: 9002
        };
        
        private const DEFAULT_TOR_CLIENT_ADDR:Object = {
            host: "127.0.0.1",
            port: 3333
        };
        
        /* David's relay (nickname 3VXRyxz67OeRoqHn) that also serves a
           crossdomain policy. */
        private const DEFAULT_TOR_RELAY_ADDR:Object = {
            host: "173.255.221.44",
            port: 9001
        };
        
        /* Poll facilitator every 10 sec */
        private const DEFAULT_FAC_POLL_INTERVAL:uint = 10000;

        // Socket to Cirrus server
        private var s_c:CirrusSocket;
        // Socket to facilitator.
        private var s_f:FacilitatorSocket;
        // Handle local-remote traffic
        private var p_p:ProxyPair;
        
        private var proxy_pairs:Array;

        private var proxy_mode:Boolean;

        /* TextField for debug output. */
        private var output_text:TextField;

        private var fac_addr:Object;
        private var relay_addr:Object;

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
            addChild(output_text);
            
            puts("Starting.");
            // Wait until the query string parameters are loaded.
            this.loaderInfo.addEventListener(Event.COMPLETE, loaderinfo_complete);
        }
        
        public function puts(s:String):void
        {
            output_text.appendText(s + "\n");
            output_text.scrollV = output_text.maxScrollV;
        }

        private function loaderinfo_complete(e:Event):void
        {
            var fac_spec:String;
            var relay_spec:String;
            
            puts("Parameters loaded.");

            proxy_mode = (this.loaderInfo.parameters["proxy"] != null);
            proxy_pairs = new Array();

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
            
            relay_spec = this.loaderInfo.parameters["relay"];
            if (relay_spec) {
                puts("Relay spec: \"" + relay_spec + "\"");
                relay_addr = parse_addr_spec(relay_spec);
                if (!relay_addr) {
                    puts("Error: Relay spec must be in the form \"host:port\".");
                    return;
                }
            } else {
                if (proxy_mode) {
                    relay_addr = DEFAULT_TOR_RELAY_ADDR;
                } else {
                    relay_addr = DEFAULT_TOR_CLIENT_ADDR;
                }
            }

            main();
        }

        /* The main logic begins here, after start-up issues are taken care of. */
        private function main():void
        {
            establish_cirrus_connection();
        }

        private function establish_cirrus_connection():void
        {
            s_c = new CirrusSocket();
            s_c.addEventListener(CirrusSocketEvent.CONNECT_SUCCESS, function (e:CirrusSocketEvent):void {
                puts("Cirrus: connected with id " + s_c.id + ".");
                establish_facilitator_connection();
            });
            s_c.addEventListener(CirrusSocketEvent.CONNECT_FAILED, function (e:CirrusSocketEvent):void {
                puts("Error: failed to connect to Cirrus.");
            });
            s_c.addEventListener(CirrusSocketEvent.CONNECT_CLOSED, function (e:CirrusSocketEvent):void {
                puts("Cirrus: closed connection.");
            });
            
            s_c.addEventListener(CirrusSocketEvent.HELLO_RECEIVED, function (e:CirrusSocketEvent):void {
                puts("Cirrus: received hello from peer " + e.peer);
                
                /* don't bother if we already have a proxy going */
                if (p_p != null && p_p.connected) {
                    return;
                }
                
                /* if we're in proxy mode, we should have already set
                   up a proxy pair */
                if (!proxy_mode) {
                    start_proxy_pair();
                    s_c.send_hello(e.peer);
                }
                p_p.connect(e.peer, e.stream);
            });
            
            s_c.connect(DEFAULT_CIRRUS_ADDR, DEFAULT_CIRRUS_KEY);
        }

        private function establish_facilitator_connection():void
        {
            s_f = new FacilitatorSocket(fac_addr.host, fac_addr.port);
            s_f.addEventListener(FacilitatorSocketEvent.CONNECT_FAILED, function (e:Event):void {
                puts("Facilitator: connect failed.");
                setTimeout(establish_facilitator_connection, DEFAULT_FAC_POLL_INTERVAL);
            });
            
            if (proxy_mode) {
                s_f.addEventListener(FacilitatorSocketEvent.REGISTRATION_RECEIVED, function (e:FacilitatorSocketEvent):void {
                    puts("Facilitator: got registration " + e.client);
                    start_proxy_pair();
                    s_c.send_hello(e.client);
                });
                s_f.addEventListener(FacilitatorSocketEvent.REGISTRATIONS_EMPTY, function (e:Event):void {
                    puts("Facilitator: no registrations available.");
                    setTimeout(establish_facilitator_connection, DEFAULT_FAC_POLL_INTERVAL);
                });
                puts("Facilitator: getting registration.");
                s_f.get_registration();
            } else {
                s_f.addEventListener(FacilitatorSocketEvent.REGISTRATION_FAILED, function (e:Event):void {
                    puts("Facilitator: registration failed.");
                    setTimeout(establish_facilitator_connection, DEFAULT_FAC_POLL_INTERVAL);
                });
                puts("Facilitator: posting registration.");
                s_f.post_registration(s_c.id);
            }
        }
        
        private function start_proxy_pair():void
        {
            puts("Starting proxy pair on stream " + s_c.local_stream_name);
            p_p = new ProxyPair(this, s_c, relay_addr.host, relay_addr.port);
            p_p.addEventListener(Event.CONNECT, function (e:Event):void {
                puts("ProxyPair: connected!");
            });
            p_p.addEventListener(Event.CLOSE, function (e:Event):void {
                puts("ProxyPair: connection closed.");
                p_p = null;
                establish_facilitator_connection();
            });
            p_p.listen(s_c.local_stream_name);
        }

        /* Parse an address in the form "host:port". Returns an Object with
           keys "host" (String) and "port" (int). Returns null on error. */
        private function parse_addr_spec(spec:String):Object
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
