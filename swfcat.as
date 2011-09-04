package
{
    import flash.display.Sprite;
    import flash.display.StageAlign;
    import flash.display.StageScaleMode;
    import flash.text.TextField;
    import flash.text.TextFormat;
    import flash.net.Socket;
    import flash.net.URLLoader;
    import flash.net.URLLoaderDataFormat;
    import flash.net.URLRequest;
    import flash.net.URLRequestMethod;
    import flash.net.URLVariables;
    import flash.events.Event;
    import flash.events.IOErrorEvent;
    import flash.events.SecurityErrorEvent;
    import flash.utils.setTimeout;

    public class swfcat extends Sprite
    {
        private const RTMFP_URL:String = "rtmfp://tor-facilitator.bamsoftware.com";

        private const DEFAULT_FACILITATOR_ADDR:Object = {
            host: "tor-facilitator.bamsoftware.com",
            port: 9002
        };

        /* Local Tor client to use in case of RTMFP connection. */
        private const DEFAULT_LOCAL_TOR_CLIENT_ADDR:Object = {
            host: "127.0.0.1",
            port: 9002
        };

        private const MAX_NUM_PROXY_PAIRS:uint = 100;

        // Milliseconds.
        private const FACILITATOR_POLL_INTERVAL:int = 1000;

        // Bytes per second. Set to undefined to disable limit.
        public static const RATE_LIMIT:Number = undefined;
        // Seconds.
        private static const RATE_LIMIT_HISTORY:Number = 5.0;

        /* TextField for debug output. */
        private var output_text:TextField;

        /* UI shown when debug is off. */
        private var badge:Badge;

        /* Proxy pairs currently connected (up to MAX_NUM_PROXY_PAIRS). */
        private var proxy_pairs:Array;

        private var fac_addr:Object;
        
        private var local_addr:Object;

        public var debug:Boolean;

        public var rate_limit:RateLimit;

        public function puts(s:String):void
        {
            if (output_text) {
                output_text.appendText(s + "\n");
                output_text.scrollV = output_text.maxScrollV;
            }
        }

        public function swfcat()
        {
            // Absolute positioning.
            stage.scaleMode = StageScaleMode.NO_SCALE;
            stage.align = StageAlign.TOP_LEFT;

            badge = new Badge();

            proxy_pairs = [];

            if (RATE_LIMIT)
                rate_limit = new BucketRateLimit(RATE_LIMIT * RATE_LIMIT_HISTORY, RATE_LIMIT_HISTORY);
            else
                rate_limit = new RateUnlimit();

            // Wait until the query string parameters are loaded.
            this.loaderInfo.addEventListener(Event.COMPLETE, loaderinfo_complete);
        }

        private function loaderinfo_complete(e:Event):void
        {
            debug = this.loaderInfo.parameters["debug"];

            if (debug || this.loaderInfo.parameters["client"]) {
                output_text = new TextField();
                output_text.width = stage.stageWidth;
                output_text.height = stage.stageHeight;
                output_text.background = true;
                output_text.backgroundColor = 0x001f0f;
                output_text.textColor = 0x44cc44;
                addChild(output_text);
            } else {
                addChild(badge);
            }

            puts("Parameters loaded.");

            fac_addr = get_param_addr("facilitator", DEFAULT_FACILITATOR_ADDR);
            if (!fac_addr) {
                puts("Error: Facilitator spec must be in the form \"host:port\".");
                return;
            }

            local_addr = get_param_addr("local", DEFAULT_LOCAL_TOR_CLIENT_ADDR);
            if (!local_addr) {
                puts("Error: Local spec must be in the form \"host:port\".");
                return;
            }

            if (this.loaderInfo.parameters["client"])
                client_main();
            else
                proxy_main();
        }

        /* Get an address structure from the given movie parameter, or the given
           default. Returns null on error. */
        private function get_param_addr(param:String, default_addr:Object):Object
        {
            var spec:String;

            spec = this.loaderInfo.parameters[param];
            if (spec)
                return parse_addr_spec(spec);
            else
                return default_addr;
        }

        /* Are circumstances such that we should self-disable and not be a
           proxy? We take a best-effort guess as to whether this device runs on
           a battery or the data transfer might be expensive. */
        private function should_disable():Boolean
        {
            return false;
        }

        /* The main logic begins here, after start-up issues are taken care of. */
        private function proxy_main():void
        {
            var fac_url:String;
            var loader:URLLoader;

            if (should_disable()) {
                puts("Disabling self.");
                return;
            }

            if (proxy_pairs.length >= MAX_NUM_PROXY_PAIRS) {
                setTimeout(proxy_main, FACILITATOR_POLL_INTERVAL);
                return;
            }

            loader = new URLLoader();
            /* Get the x-www-form-urlencoded values. */
            loader.dataFormat = URLLoaderDataFormat.VARIABLES;
            loader.addEventListener(Event.COMPLETE, fac_complete);
            loader.addEventListener(IOErrorEvent.IO_ERROR, function (e:IOErrorEvent):void {
                puts("Facilitator: I/O error: " + e.text + ".");
            });
            loader.addEventListener(SecurityErrorEvent.SECURITY_ERROR, function (e:SecurityErrorEvent):void {
                puts("Facilitator: security error: " + e.text + ".");
            });

            fac_url = "http://" + encodeURIComponent(fac_addr.host)
                + ":" + encodeURIComponent(fac_addr.port) + "/";
            puts("Facilitator: connecting to " + fac_url + ".");
            loader.load(new URLRequest(fac_url));
        }

        private function fac_complete(e:Event):void
        {
            var loader:URLLoader;
            var client_spec:String;
            var relay_spec:String;
            var proxy_pair:Object;

            setTimeout(proxy_main, FACILITATOR_POLL_INTERVAL);

            loader = e.target as URLLoader;
            client_spec = loader.data.client;
            if (client_spec == "") {
                puts("No clients.");
                return;
            } else if (!client_spec) {
                puts("Error: missing \"client\" in response.");
                return;
            }
            relay_spec = loader.data.relay;
            if (!relay_spec) {
                puts("Error: missing \"relay\" in response.");
                return;
            }
            puts("Facilitator: got client:\"" + client_spec + "\" "
                + "relay:\"" + relay_spec + "\".");

            try {
                proxy_pair = make_proxy_pair(client_spec, relay_spec);
            } catch (e:ArgumentError) {
                puts("Error: " + e);
                return;
            }
            proxy_pairs.push(proxy_pair);
            proxy_pair.addEventListener(Event.COMPLETE, function(e:Event):void {
                proxy_pair.log("Complete.");
                /* Delete from the list of active proxy pairs. */
                proxy_pairs.splice(proxy_pairs.indexOf(proxy_pair), 1);
                badge.proxy_end();
            });
            proxy_pair.connect();

            badge.proxy_begin();
        }

        private function client_main():void
        {
            var rs:RTMFPSocket;

            rs = new RTMFPSocket(RTMFP_URL);
            rs.addEventListener(Event.COMPLETE, function (e:Event):void {
                puts("Got RTMFP id " + rs.id);
                register(rs);
            });
            rs.addEventListener(RTMFPSocket.ACCEPT_EVENT, client_accept);

            rs.listen();
        }

        private function client_accept(e:Event):void {
            var rs:RTMFPSocket;
            var s_t:Socket;
            var proxy_pair:ProxyPair;

            rs = e.target as RTMFPSocket;
            s_t = new Socket();

            puts("Got RTMFP connection from " + rs.peer_id);

            proxy_pair = new ProxyPair(this, rs, function ():void {
                /* Do nothing; already connected. */
            }, s_t, function ():void {
                s_t.connect(local_addr.host, local_addr.port);
            });
            proxy_pair.connect();
        }

        private function register(rs:RTMFPSocket):void {
            var fac_url:String;
            var loader:URLLoader;
            var request:URLRequest;

            loader = new URLLoader();
            loader.addEventListener(Event.COMPLETE, function (e:Event):void {
                puts("Facilitator: registered.");
            });
            loader.addEventListener(SecurityErrorEvent.SECURITY_ERROR, function (e:SecurityErrorEvent):void {
                puts("Facilitator: security error: " + e.text + ".");
                rs.close();
            });
            loader.addEventListener(IOErrorEvent.IO_ERROR, function (e:IOErrorEvent):void {
                puts("Facilitator: I/O error: " + e.text + ".");
                rs.close();
            });

            fac_url = "http://" + encodeURIComponent(fac_addr.host)
                + ":" + encodeURIComponent(fac_addr.port) + "/";
            request = new URLRequest(fac_url);
            request.method = URLRequestMethod.POST;
            request.data = new URLVariables();
            request.data["client"] = rs.id;

            puts("Facilitator: connecting to " + fac_url + ".");
            loader.load(request);
        }

        private function make_proxy_pair(client_spec:String, relay_spec:String):ProxyPair
        {
            var proxy_pair:ProxyPair;
            var addr_c:Object;
            var addr_r:Object;
            var s_c:*;
            var s_r:Socket;

            addr_r = swfcat.parse_addr_spec(relay_spec);
            if (!addr_r)
                throw new ArgumentError("Relay spec must be in the form \"host:port\".");

            addr_c = swfcat.parse_addr_spec(client_spec);
            if (addr_c) {
                s_c = new Socket();
                s_r = new Socket();
                proxy_pair = new ProxyPair(this, s_c, function ():void {
                    s_c.connect(addr_c.host, addr_c.port);
                }, s_r, function ():void {
                    s_r.connect(addr_r.host, addr_r.port);
                });
                proxy_pair.set_name("<" + addr_c.host + ":" + addr_c.port + ","
                    + addr_r.host + ":" + addr_r.port + ">");
                return proxy_pair;
            }

            if (client_spec.match(/^[0-9A-Fa-f]{64}$/)) {
                s_c = new RTMFPSocket(RTMFP_URL);
                s_r = new Socket();
                proxy_pair = new ProxyPair(this, s_c, function ():void {
                    s_c.connect(client_spec);
                }, s_r, function ():void {
                    s_r.connect(addr_r.host, addr_r.port);
                });
                proxy_pair.set_name("<" + client_spec.substr(0, 4) + "...,"
                    + addr_r.host + ":" + addr_r.port + ">");
                return proxy_pair;
            }

            throw new ArgumentError("Can't parse client spec \"" + client_spec + "\".");
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

import flash.text.TextFormat;
import flash.text.TextField;
import flash.utils.getTimer;

class Badge extends flash.display.Sprite
{
    /* Number of proxy pairs currently connected. */
    private var num_proxy_pairs:int = 0;
    /* Number of proxy pairs ever connected. */
    private var total_proxy_pairs:int = 0;

    [Embed(source="badge.png")]
    private var BadgeImage:Class;
    private var tot_client_count_tf:TextField;
    private var tot_client_count_fmt:TextFormat;
    private var cur_client_count_tf:TextField;
    private var cur_client_count_fmt:TextFormat;

    public function Badge()
    {
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

        addChild(new BadgeImage());
        addChild(tot_client_count_tf);
        addChild(cur_client_count_tf);

        /* Update the client counter on badge. */
        update_client_count();
    }

    public function proxy_begin():void
    {
        num_proxy_pairs++;
        total_proxy_pairs++;
        update_client_count();
    }

    public function proxy_end():void
    {
        num_proxy_pairs--;
        update_client_count();
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

class RateLimit
{
    public function RateLimit()
    {
    }

    public function update(n:Number):Boolean
    {
        return true;
    }

    public function when():Number
    {
        return 0.0;
    }

    public function is_limited():Boolean
    {
        return false;
    }
}

class RateUnlimit extends RateLimit
{
    public function RateUnlimit()
    {
    }

    public override function update(n:Number):Boolean
    {
        return true;
    }

    public override function when():Number
    {
        return 0.0;
    }

    public override function is_limited():Boolean
    {
        return false;
    }
}

class BucketRateLimit extends RateLimit
{
    private var amount:Number;
    private var capacity:Number;
    private var time:Number;
    private var last_update:uint;

    public function BucketRateLimit(capacity:Number, time:Number)
    {
        this.amount = 0.0;
        /* capacity / time is the rate we are aiming for. */
        this.capacity = capacity;
        this.time = time;
        this.last_update = getTimer();
    }

    private function age():void
    {
        var now:uint;
        var delta:Number;

        now = getTimer();
        delta = (now - last_update) / 1000.0;
        last_update = now;

        amount -= delta * capacity / time;
        if (amount < 0.0)
            amount = 0.0;
    }

    public override function update(n:Number):Boolean
    {
        age();
        amount += n;

        return amount <= capacity;
    }

    public override function when():Number
    {
        age();
        return (amount - capacity) / (capacity / time);
    }

    public override function is_limited():Boolean
    {
        age();
        return amount > capacity;
    }
}
