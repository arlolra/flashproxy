package
{
    import flash.display.Sprite;
    import flash.text.TextField;
    import flash.net.Socket;
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
        private const DEFAULT_TOR_ADDR:Object = {
            host: "173.255.221.44",
            port: 9001
        };

        // Socket to facilitator.
        private var s_f:Socket;

        private var output_text:TextField;

        private var fac_addr:Object;

        public function puts(s:String):void
        {
            output_text.appendText(s + "\n");
            output_text.scrollV = output_text.maxScrollV;
        }

        public function swfcat()
        {
            output_text = new TextField();
            output_text.width = 400;
            output_text.height = 300;
            output_text.background = true;
            output_text.backgroundColor = 0x001f0f;
            output_text.textColor = 0x44CC44;
            addChild(output_text);

            puts("Starting.");
            // Wait until the query string parameters are loaded.
            this.loaderInfo.addEventListener(Event.COMPLETE, loaderinfo_complete);
        }

        private function loaderinfo_complete(e:Event):void
        {
            var fac_spec:String;

            puts("Parameters loaded.");
            fac_spec = this.loaderInfo.parameters["facilitator"];
            if (!fac_spec) {
                puts("Error: no \"facilitator\" specification provided.");
                return;
            }
            puts("Facilitator spec: \"" + fac_spec + "\"");
            fac_addr = parse_addr_spec(fac_spec);
            if (!fac_addr) {
                puts("Error: Facilitator spec must be in the form \"host:port\".");
                return;
            }

            main();
        }

        /* The main logic begins here, after start-up issues are taken care of. */
        private function main():void
        {
            s_f = new Socket();

            s_f.addEventListener(Event.CONNECT, fac_connected);
            s_f.addEventListener(Event.CLOSE, function (e:Event):void {
                puts("Facilitator: closed connection.");
            });
            s_f.addEventListener(IOErrorEvent.IO_ERROR, function (e:IOErrorEvent):void {
                puts("Facilitator: I/O error: " + e.text + ".");
            });
            s_f.addEventListener(SecurityErrorEvent.SECURITY_ERROR, function (e:SecurityErrorEvent):void {
                puts("Facilitator: security error: " + e.text + ".");
            });

            puts("Facilitator: connecting to " + fac_addr.host + ":" + fac_addr.port + ".");
            s_f.connect(fac_addr.host, fac_addr.port);
        }

        private function fac_connected(e:Event):void
        {
            puts("Facilitator: connected.");

            s_f.addEventListener(ProgressEvent.SOCKET_DATA, fac_data);

            s_f.writeUTFBytes("GET / HTTP/1.0\r\n\r\n");
        }

        private function fac_data(e:ProgressEvent):void
        {
            var client_spec:String;
            var client_addr:Object;
            var proxy_pair:Object;

            client_spec = s_f.readMultiByte(e.bytesLoaded, "utf-8");
            puts("Facilitator: got \"" + client_spec + "\"");

            client_addr = parse_addr_spec(client_spec);
            if (!client_addr) {
                puts("Error: Client spec must be in the form \"host:port\".");
                setTimeout(main, 1000);
                return;
            }
            if (client_addr.host == "0.0.0.0" && client_addr.port == 0) {
                puts("Error: Facilitator has no clients.");
                setTimeout(main, 1000);
                return;
            }

            proxy_pair = new ProxyPair(this, client_addr, DEFAULT_TOR_ADDR);
            proxy_pair.connect();

            setTimeout(main, 1000); 
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
import flash.events.IOErrorEvent;
import flash.events.ProgressEvent;
import flash.events.SecurityErrorEvent;
import flash.net.Socket;
import flash.utils.ByteArray;

/* An instance of a client-relay connection. */
class ProxyPair
{
    // Address ({host, port}) of client.
    private var addr_c:Object;
    // Address ({host, port}) of relay.
    private var addr_r:Object;

    // Socket to client.
    private var s_c:Socket;
    // Socket to relay.
    private var s_r:Socket;

    // Parent swfcat, for UI updates.
    private var ui:swfcat;

    private function log(msg:String):void
    {
        ui.puts(id() + ": " + msg)
    }

    // String describing this pair for output.
    private function id():String
    {
        return "<" + this.addr_c.host + ":" + this.addr_c.port +
            "," + this.addr_r.host + ":" + this.addr_r.port + ">";
    }

    public function ProxyPair(ui:swfcat, addr_c:Object, addr_r:Object)
    {
        this.ui = ui;
        this.addr_c = addr_c;
        this.addr_r = addr_r;
    }

    public function connect():void
    {
        s_r = new Socket();

        s_r.addEventListener(Event.CONNECT, tor_connected);
        s_r.addEventListener(Event.CLOSE, function (e:Event):void {
            log("Tor: closed.");
            if (s_c.connected)
                s_c.close();
        });
        s_r.addEventListener(IOErrorEvent.IO_ERROR, function (e:IOErrorEvent):void {
            log("Tor: I/O error: " + e.text + ".");
            if (s_c.connected)
                s_c.close();
        });
        s_r.addEventListener(SecurityErrorEvent.SECURITY_ERROR, function (e:SecurityErrorEvent):void {
            log("Tor: security error: " + e.text + ".");
            if (s_c.connected)
                s_c.close();
        });

        log("Tor: connecting to " + addr_r.host + ":" + addr_r.port + ".");
        s_r.connect(addr_r.host, addr_r.port);
    }

    private function tor_connected(e:Event):void
    {
        log("Tor: connected.");

        s_c = new Socket();

        s_c.addEventListener(Event.CONNECT, client_connected);
        s_c.addEventListener(Event.CLOSE, function (e:Event):void {
            log("Client: closed.");
            if (s_r.connected)
                s_r.close();
        });
        s_c.addEventListener(IOErrorEvent.IO_ERROR, function (e:IOErrorEvent):void {
            log("Client: I/O error: " + e.text + ".");
            if (s_r.connected)
                s_r.close();
        });
        s_c.addEventListener(SecurityErrorEvent.SECURITY_ERROR, function (e:SecurityErrorEvent):void {
            log("Client: security error: " + e.text + ".");
            if (s_r.connected)
                s_r.close();
        });

        log("Client: connecting to " + addr_c.host + ":" + addr_c.port + ".");
        s_c.connect(addr_c.host, addr_c.port);
    }

    private function client_connected(e:Event):void
    {
        log("Client: connected.");

        s_r.addEventListener(ProgressEvent.SOCKET_DATA, function (e:ProgressEvent):void {
            var bytes:ByteArray = new ByteArray();
            s_r.readBytes(bytes, 0, e.bytesLoaded);
            log("Tor: read " + bytes.length + ".");
            s_c.writeBytes(bytes);
        });
        s_c.addEventListener(ProgressEvent.SOCKET_DATA, function (e:ProgressEvent):void {
            var bytes:ByteArray = new ByteArray();
            s_c.readBytes(bytes, 0, e.bytesLoaded);
            log("Client: read " + bytes.length + ".");
            s_r.writeBytes(bytes);
        });
    }
}
