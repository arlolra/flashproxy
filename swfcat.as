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
    import flash.events.Event;
    import flash.events.IOErrorEvent;
    import flash.events.ProgressEvent;
    import flash.events.SecurityErrorEvent;
    import flash.utils.ByteArray;
    import flash.utils.setTimeout;

    public class swfcat extends Sprite
    {
        /* David's relay (nickname 3VXRyxz67OeRoqHn) that also serves a
           crossdomain policy. */
        private const DEFAULT_RELAY_ADDR:Object = {
            host: "173.255.221.44",
            port: 9001
        };
        private const DEFAULT_FACILITATOR_ADDR:Object = {
            host: "tor-facilitator.bamsoftware.com",
            port: 9002
        };

        private const MAX_NUM_PROXY_PAIRS:uint = 1;

        // Milliseconds.
        private const FACILITATOR_POLL_INTERVAL:int = 10000;

        // Bytes per second. Set to undefined to disable limit.
        public const RATE_LIMIT:Number = undefined;
        // Seconds.
        private const RATE_LIMIT_HISTORY:Number = 5.0;

        /* TextField for debug output. */
        private var output_text:TextField;

        private var fac_addr:Object;
        private var relay_addr:Object;

        /* Number of proxy pairs currently connected (up to
           MAX_NUM_PROXY_PAIRS). */
        private var num_proxy_pairs:int = 0;
        /* Number of proxy pairs ever connected. */
        private var total_proxy_pairs:int = 0;

        public var rate_limit:RateLimit;

        /* Badge with a client counter */
        [Embed(source="badge.png")]
        private var BadgeImage:Class;
        private var tot_client_count_tf:TextField;
        private var tot_client_count_fmt:TextFormat;
        private var cur_client_count_tf:TextField;
        private var cur_client_count_fmt:TextFormat;

        public function puts(s:String):void
        {
            output_text.appendText(s + "\n");
            output_text.scrollV = output_text.maxScrollV;
        }

        public function update_client_count():void
        {
            /* Update total client count. */
            if (String(total_proxy_pairs).length == 1)
                tot_client_count_tf.text = "0" + String(total_proxy_pairs);
            else
                tot_client_count_tf.text = String(total_proxy_pairs);

            /* Update current client count. */
            cur_client_count_tf.text = "";
            for(var i:Number=0; i<num_proxy_pairs; i++)
                cur_client_count_tf.appendText(".");;
        }

        public function swfcat()
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

            if (RATE_LIMIT)
                rate_limit = new BucketRateLimit(RATE_LIMIT * RATE_LIMIT_HISTORY, RATE_LIMIT_HISTORY);
            else
                rate_limit = new RateUnlimit();

            puts("Starting.");
            // Wait until the query string parameters are loaded.
            this.loaderInfo.addEventListener(Event.COMPLETE, loaderinfo_complete);
        }

        private function loaderinfo_complete(e:Event):void
        {
            var fac_spec:String;

            puts("Parameters loaded.");

            if (this.loaderInfo.parameters["debug"])
                addChild(output_text);
            else {
                addChild(new BadgeImage());
                /* Tried unsuccessfully to add counter to badge. */
                /* For now, need two addChilds :( */
                addChild(tot_client_count_tf);
                addChild(cur_client_count_tf);
            }

            fac_addr = get_param_addr("facilitator", DEFAULT_FACILITATOR_ADDR);
            if (!fac_addr) {
                puts("Error: Facilitator spec must be in the form \"host:port\".");
                return;
            }
            relay_addr = get_param_addr("relay", DEFAULT_RELAY_ADDR);
            if (!relay_addr) {
                puts("Error: Relay spec must be in the form \"host:port\".");
                return;
            }

            main();
        }

        /* Get an address structure from the given movie parameter, or the given
           default. Returns null on error. */
        private function get_param_addr(param:String, default_addr:Object):Object
        {
            var spec:String, addr:Object;

            spec = this.loaderInfo.parameters[param];
            if (spec)
                return parse_addr_spec(spec);
            else
                return default_addr;
        }

        /* The main logic begins here, after start-up issues are taken care of. */
        private function main():void
        {
            var fac_url:String;
            var loader:URLLoader;

            if (num_proxy_pairs >= MAX_NUM_PROXY_PAIRS) {
                setTimeout(main, FACILITATOR_POLL_INTERVAL);
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
            var client_addr:Object;
            var proxy_pair:Object;

            setTimeout(main, FACILITATOR_POLL_INTERVAL);

            loader = e.target as URLLoader;
            client_spec = loader.data.client;
            if (client_spec == "") {
                puts("No clients.");
                return;
            } else if (!client_spec) {
                puts("Error: missing \"client\" in response.");
                return;
            }
            puts("Facilitator: got \"" + client_spec + "\".");

            client_addr = parse_addr_spec(client_spec);
            if (!client_addr) {
                puts("Error: Client spec must be in the form \"host:port\".");
                return;
            }

            num_proxy_pairs++;
            total_proxy_pairs++;
            /* Update the client count on the badge. */
            update_client_count();

            proxy_pair = new ProxyPair(this, client_addr, relay_addr);
            proxy_pair.addEventListener(Event.COMPLETE, function(e:Event):void {
                proxy_pair.log("Complete.");
                
                num_proxy_pairs--;
                /* Update the client count on the badge. */
                update_client_count();
            });
            proxy_pair.connect();

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

/* An instance of a client-relay connection. */
class ProxyPair extends EventDispatcher
{
    // Address ({host, port}) of client.
    private var addr_c:Object;
    // Address ({host, port}) of relay.
    private var addr_r:Object;

    // Socket to client.
    private var s_c:Socket;
    // Socket to relay.
    private var s_r:Socket;

    // Parent swfcat, for UI updates and rate meter.
    private var ui:swfcat;

    // Pending byte read counts for relay and client sockets.
    private var r2c_schedule:Array;
    private var c2r_schedule:Array;
    // Callback id.
    private var flush_id:uint;

    public function log(msg:String):void
    {
        ui.puts(id() + ": " + msg)
    }

    // String describing this pair for output.
    public function id():String
    {
        return "<" + this.addr_c.host + ":" + this.addr_c.port +
            "," + this.addr_r.host + ":" + this.addr_r.port + ">";
    }

    public function ProxyPair(ui:swfcat, addr_c:Object, addr_r:Object)
    {
        this.ui = ui;
        this.addr_c = addr_c;
        this.addr_r = addr_r;

        this.c2r_schedule = [];
        this.r2c_schedule = [];
    }

    public function connect():void
    {
        s_r = new Socket();

        s_r.addEventListener(Event.CONNECT, relay_connected);
        s_r.addEventListener(Event.CLOSE, function (e:Event):void {
            log("Relay: closed.");
            if (s_c.connected)
                s_c.close();
            dispatchEvent(new Event(Event.COMPLETE));
        });
        s_r.addEventListener(IOErrorEvent.IO_ERROR, function (e:IOErrorEvent):void {
            log("Relay: I/O error: " + e.text + ".");
            if (s_c.connected)
                s_c.close();
            dispatchEvent(new Event(Event.COMPLETE));
        });
        s_r.addEventListener(SecurityErrorEvent.SECURITY_ERROR, function (e:SecurityErrorEvent):void {
            log("Relay: security error: " + e.text + ".");
            if (s_c.connected)
                s_c.close();
            dispatchEvent(new Event(Event.COMPLETE));
        });
        s_r.addEventListener(ProgressEvent.SOCKET_DATA, relay_to_client);

        log("Relay: connecting to " + addr_r.host + ":" + addr_r.port + ".");
        s_r.connect(addr_r.host, addr_r.port);
    }

    private function relay_connected(e:Event):void
    {
        log("Relay: connected.");

        s_c = new Socket();

        s_c.addEventListener(Event.CONNECT, client_connected);
        s_c.addEventListener(Event.CLOSE, function (e:Event):void {
            log("Client: closed.");
            if (s_r.connected)
                s_r.close();
            dispatchEvent(new Event(Event.COMPLETE));
        });
        s_c.addEventListener(IOErrorEvent.IO_ERROR, function (e:IOErrorEvent):void {
            log("Client: I/O error: " + e.text + ".");
            if (s_r.connected)
                s_r.close();
            dispatchEvent(new Event(Event.COMPLETE));
        });
        s_c.addEventListener(SecurityErrorEvent.SECURITY_ERROR, function (e:SecurityErrorEvent):void {
            log("Client: security error: " + e.text + ".");
            if (s_r.connected)
                s_r.close();
            dispatchEvent(new Event(Event.COMPLETE));
        });
        s_c.addEventListener(ProgressEvent.SOCKET_DATA, client_to_relay);

        log("Client: connecting to " + addr_c.host + ":" + addr_c.port + ".");
        s_c.connect(addr_c.host, addr_c.port);
    }

    private function relay_to_client(e:ProgressEvent):void
    {
        r2c_schedule.push(e.bytesLoaded);
        flush();
    }

    private function client_to_relay(e:ProgressEvent):void
    {
        c2r_schedule.push(e.bytesLoaded);
        flush();
    }

    private function client_connected(e:Event):void
    {
        log("Client: connected.");
    }

    private function transfer_chunk(s_from:Socket, s_to:Socket, n:uint,
        label:String):void
    {
        var bytes:ByteArray;

        bytes = new ByteArray();
        s_from.readBytes(bytes, 0, n);
        s_to.writeBytes(bytes);
        ui.rate_limit.update(n);
        log(label + ": read " + bytes.length + ".");
    }

    /* Send as much data as the rate limit currently allows. */
    private function flush():void
    {
        if (flush_id)
            clearTimeout(flush_id);
        flush_id = undefined;

        if (!(s_r.connected && s_c.connected))
            /* Can't do anything until both sockets are connected. */
            return;

        while (!ui.rate_limit.is_limited() &&
               (r2c_schedule.length > 0 || c2r_schedule.length > 0)) {
            if (r2c_schedule.length > 0)
                transfer_chunk(s_r, s_c, r2c_schedule.shift(), "Relay");
            if (c2r_schedule.length > 0)
                transfer_chunk(s_c, s_r, c2r_schedule.shift(), "Client");
        }

        /* Call again when safe, if necessary. */
        if (r2c_schedule.length > 0 || c2r_schedule.length > 0)
            flush_id = setTimeout(flush, ui.rate_limit.when() * 1000);
    }
}
