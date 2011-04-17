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

    public class swfcat extends Sprite
    {
        private const TOR_ADDRESS:String = "173.255.221.44";
        private const TOR_PORT:int = 9001;

        private var output_text:TextField;

        // Socket to Tor relay.
        private var s_t:Socket;
        // Socket to client.
        private var s_c:Socket;

        private var client_address:String;
        private var client_port:int;

        private function puts(s:String):void
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
            var client_spec:String, parts:Array;

            puts("Parameters loaded.");
            client_spec = this.loaderInfo.parameters["client"];
            if (!client_spec) {
                puts("Error: no \"client\" specification provided.");
                return;
            }
            puts("Client spec: \"" + client_spec + "\"");
            parts = client_spec.split(":", 2);
            if (parts.length != 2 || !parseInt(parts[1])) {
                puts("Error: client spec must be in the form \"host:port\".");
                return;
            }
            client_address = parts[0];
            client_port = parseInt(parts[1]);

            go(TOR_ADDRESS, TOR_PORT);
        }

        /* We connect first to the Tor relay; once that happens we connect to
           the client; and when both connections exist we begin relaying data. */
        private function go(tor_address:String, tor_port:int):void
        {
            s_t = new Socket();

            s_t.addEventListener(Event.CONNECT, tor_connected);
            s_t.addEventListener(Event.CLOSE, function (e:Event):void {
                puts("Tor: closed.");
                if (s_c.connected)
                    s_c.close();
            });
            s_t.addEventListener(IOErrorEvent.IO_ERROR, function (e:IOErrorEvent):void {
                puts("Tor: I/O error: " + e.text + ".");
                if (s_c.connected)
                    s_c.close();
            });
            s_t.addEventListener(SecurityErrorEvent.SECURITY_ERROR, function (e:SecurityErrorEvent):void {
                puts("Tor: security error: " + e.text + ".");
                if (s_c.connected)
                    s_c.close();
            });

            puts("Tor: connecting to " + tor_address + ":" + tor_port + ".");
            s_t.connect(tor_address, tor_port);
        }

        private function tor_connected(e:Event):void
        {
            s_c = new Socket();

            puts("Tor: connected.");
            s_c.addEventListener(Event.CONNECT, client_connected);
            s_c.addEventListener(Event.CLOSE, function (e:Event):void {
                puts("Client: closed.");
                if (s_t.connected)
                    s_t.close();
            });
            s_c.addEventListener(IOErrorEvent.IO_ERROR, function (e:IOErrorEvent):void {
                puts("Client: I/O error: " + e.text + ".");
                if (s_t.connected)
                    s_t.close();
            });
            s_c.addEventListener(SecurityErrorEvent.SECURITY_ERROR, function (e:SecurityErrorEvent):void {
                puts("Client: security error: " + e.text + ".");
                if (s_t.connected)
                    s_t.close();
            });

            puts("Client: connecting to " + client_address + ":" + client_port + ".");
            s_c.connect(client_address, client_port);
        }

        private function client_connected(e:Event):void
        {
            puts("Client: connected.");

            s_t.addEventListener(ProgressEvent.SOCKET_DATA, function (e:ProgressEvent):void {
                var bytes:ByteArray = new ByteArray();
                s_t.readBytes(bytes, 0, e.bytesLoaded);
                puts("Tor: read " + bytes.length + ".");
                s_c.writeBytes(bytes);
            });
            s_c.addEventListener(ProgressEvent.SOCKET_DATA, function (e:ProgressEvent):void {
                var bytes:ByteArray = new ByteArray();
                s_c.readBytes(bytes, 0, e.bytesLoaded);
                puts("Client: read " + bytes.length + ".");
                s_t.writeBytes(bytes);
            });
        }
    }
}
