package
{
    import flash.display.Sprite;
    import flash.display.StageAlign;
    import flash.display.StageScaleMode;
    import flash.text.TextField;
    import flash.text.TextFormat;
    import flash.events.Event;
    import flash.utils.setTimeout;

    import FacilitatorSocket;
    import events.FacilitatorSocketEvent;
    
    import ProxyPair;
    import RTMFPProxyPair;
    import SQSProxyPair;
    import TCPProxyPair;

    import rtmfp.CirrusSocket;
    import rtmfp.events.CirrusSocketEvent;

    public class swfcat extends Sprite
    {
        /* Adobe's Cirrus server for RTMFP connections.
           The Cirrus key is defined at compile time by
           reading from the CIRRUS_KEY environment var. */
        private const DEFAULT_CIRRUS_ADDR:String = "rtmfp://p2p.rtmfp.net";
        private const DEFAULT_CIRRUS_KEY:String = RTMFP::CIRRUS_KEY;
        
        private const DEFAULT_FACILITATOR_ADDR:Object = {
            host: "tor-facilitator.bamsoftware.com",
            port: 9002
        };
        
        /* Default Tor client to use in case of RTMFP connection */
        private const DEFAULT_TOR_CLIENT_ADDR:Object = {
            host: "127.0.0.1",
            port: 9002
        };
        
        /* Poll facilitator every 10 sec */
        private const DEFAULT_FAC_POLL_INTERVAL:uint = 10000;

        // Socket to Cirrus server
        private var s_c:CirrusSocket;
        // Socket to facilitator.
        private var s_f:FacilitatorSocket;
        // Handle local-remote traffic
        private var p_p:ProxyPair;
        
        private var client_id:String;
        private var proxy_pair_factory:Function;
        
        private var proxy_pairs:Array;

        private var debug_mode:Boolean;
        private var proxy_mode:Boolean;

        /* TextField for debug output. */
        private var output_text:TextField;
        
        /* Badge for display */
        private var badge:InternetFreedomBadge;

        private var fac_addr:Object;
        private var relay_addr:Object;

        public function swfcat()
        {
            proxy_mode = false;
            debug_mode = false;
            
            // Absolute positioning.
            stage.scaleMode = StageScaleMode.NO_SCALE;
            stage.align = StageAlign.TOP_LEFT;
            
            // Wait until the query string parameters are loaded.
            this.loaderInfo.addEventListener(Event.COMPLETE, loaderinfo_complete);
        }
        
        public function puts(s:String):void
        {
            if (output_text != null) {
                output_text.appendText(s + "\n");
                output_text.scrollV = output_text.maxScrollV;
            }
        }

        private function loaderinfo_complete(e:Event):void
        {
            var fac_spec:String;
            var relay_spec:String;

            debug_mode = (this.loaderInfo.parameters["debug"] != null)
            proxy_mode = (this.loaderInfo.parameters["proxy"] != null);
            if (proxy_mode && !debug_mode) {
                badge = new InternetFreedomBadge(this);
                badge.display();
            } else {
                output_text = new TextField();
                output_text.width = stage.stageWidth;
                output_text.height = stage.stageHeight;
                output_text.background = true;
                output_text.backgroundColor = 0x001f0f;
                output_text.textColor = 0x44cc44;
                addChild(output_text);
            }
            
            puts("Starting: parameters loaded.");
            
            /* TODO: use this to have multiple proxies going at once */
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

            main();
        }

        /* The main logic begins here, after start-up issues are taken care of. */
        private function main():void
        {
            if (proxy_mode) {
                establish_facilitator_connection();
            } else {
                establish_cirrus_connection();
            }
        }

        private function establish_cirrus_connection():void
        {
            s_c = new CirrusSocket();
            s_c.addEventListener(CirrusSocketEvent.CONNECT_SUCCESS, function (e:CirrusSocketEvent):void {
                puts("Cirrus: connected with id " + s_c.id + ".");
                if (proxy_mode) {
                    start_proxy_pair();
                    s_c.send_hello(client_id);
                } else {
                    establish_facilitator_connection();
                }
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
                    relay_addr = DEFAULT_TOR_CLIENT_ADDR;
                    proxy_pair_factory = rtmfp_proxy_pair_factory;
                    start_proxy_pair();
                    s_c.send_hello(e.peer);
                } else if (!debug_mode && badge != null) {
                    badge.total_proxy_pairs++;
                    badge.num_proxy_pairs++;
                }
                
                p_p.client = {peer: e.peer, stream: e.stream};
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
                    var client_addr:Object = parse_addr_spec(e.client);
                    relay_addr = parse_addr_spec(e.relay);
                    if (client_addr == null) {
                        puts("Facilitator: got registration " + e.client);
                        proxy_pair_factory = rtmfp_proxy_pair_factory;
                        if (s_c == null || !s_c.connected) {
                            client_id = e.client;
                            establish_cirrus_connection();
                        } else {
                            start_proxy_pair();
                            s_c.send_hello(e.client);
                        }
                    } else {
                        proxy_pair_factory = tcp_proxy_pair_factory;
                        start_proxy_pair();
                        p_p.client = client_addr;
                    }
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
            p_p = proxy_pair_factory();
            p_p.addEventListener(Event.CONNECT, function (e:Event):void {
                puts("ProxyPair: connected!");
            });
            p_p.addEventListener(Event.CLOSE, function (e:Event):void {
                puts("ProxyPair: connection closed.");
                p_p = null;
                if (proxy_mode && !debug_mode && badge != null) {
                    badge.num_proxy_pairs--;
                }
                establish_facilitator_connection();
            });
            p_p.relay = relay_addr;
        }
        
        private function rtmfp_proxy_pair_factory():ProxyPair
        {
            return new RTMFPProxyPair(this, s_c, s_c.local_stream_name);
        }
        
        // currently is the same as TCPProxyPair
        // could be interesting to see how this works
        // can't imagine it will work terribly well...
        private function sqs_proxy_pair_factory():ProxyPair
        {
            return new SQSProxyPair(this);
        }
        
        private function tcp_proxy_pair_factory():ProxyPair
        {
            return new TCPProxyPair(this);
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

import flash.text.TextField;
import flash.text.TextFormat;

class InternetFreedomBadge {
    
    private var ui:swfcat;
    
    private var _num_proxy_pairs:uint;
    private var _total_proxy_pairs:uint;
    
    [Embed(source="badge.png")]
    private var BadgeImage:Class;
    private var tot_client_count_tf:TextField;
    private var tot_client_count_fmt:TextFormat;
    private var cur_client_count_tf:TextField;
    private var cur_client_count_fmt:TextFormat;
    
    public function InternetFreedomBadge(ui:swfcat)
    {
        this.ui = ui;
        _num_proxy_pairs = 0;
        _total_proxy_pairs = 0;
        
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
    }
    
    public function display():void
    {
        ui.addChild(new BadgeImage());
        /* Tried unsuccessfully to add counter to badge. */
        /* For now, need two addChilds :( */
        ui.addChild(tot_client_count_tf);
        ui.addChild(cur_client_count_tf);
    }
    
    public function get num_proxy_pairs():uint
    {
        return _num_proxy_pairs;
    }
    
    public function set num_proxy_pairs(amount:uint):void
    {
        _num_proxy_pairs = amount;
        update_client_count();
    }
    
    public function get total_proxy_pairs():uint
    {
        return _total_proxy_pairs;
    }
    
    public function set total_proxy_pairs(amount:uint):void
    {
        _total_proxy_pairs = amount;
        /* note: doesn't update, so be sure to update this
           before you update num_proxy_pairs! */
    }
    
    private function update_client_count():void
    {
        /* Update total client count. */
        if (String(total_proxy_pairs).length == 1)
            tot_client_count_tf.text = "0" + String(total_proxy_pairs);
        else
            tot_client_count_tf.text = String(total_proxy_pairs);

        /* Update current client count. */
        cur_client_count_tf.text = "";
        for(var i:Number = 0; i < num_proxy_pairs; i++)
            cur_client_count_tf.appendText(".");
    }
}
