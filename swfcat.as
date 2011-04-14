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
        private const CLIENT_ADDRESS:String = "192.168.0.2";
        private const CLIENT_PORT:int = 9001;

        private var output_text:TextField;

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
            var client_address:String, client_port:int;

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

            go(TOR_ADDRESS, TOR_PORT, client_address, client_port);
        }

        private function go(tor_address:String, tor_port:int,
            client_address:String, client_port:int):void
        {
            var s_t:Socket = new Socket();
            var s_c:Socket = new Socket();

            s_t.addEventListener(Event.CONNECT, function (e:Event):void {
                puts("Tor: connected.");
            });
            s_t.addEventListener(Event.CLOSE, function (e:Event):void {
                puts("Tor: closed.");
            });
            s_t.addEventListener(IOErrorEvent.IO_ERROR, function (e:IOErrorEvent):void {
                puts("Tor: I/O error: " + e.text + ".");
            });
            s_t.addEventListener(SecurityErrorEvent.SECURITY_ERROR, function (e:SecurityErrorEvent):void {
                puts("Tor: security error: " + e.text + ".");
            });
            s_t.addEventListener(ProgressEvent.SOCKET_DATA, function (e:ProgressEvent):void {
                var bytes:ByteArray = new ByteArray();
                s_t.readBytes(bytes, 0, e.bytesLoaded);
                puts("Tor: read " + bytes.length + ".");
                s_c.writeBytes(bytes);
            });

            s_c.addEventListener(Event.CONNECT, function (e:Event):void {
                puts("Client: connected.");
            });
            s_c.addEventListener(Event.CLOSE, function (e:Event):void {
                puts("Client: closed.");
            });
            s_c.addEventListener(IOErrorEvent.IO_ERROR, function (e:IOErrorEvent):void {
                puts("Client: I/O error: " + e.text + ".");
            });
            s_c.addEventListener(SecurityErrorEvent.SECURITY_ERROR, function (e:SecurityErrorEvent):void {
                puts("Client: security error: " + e.text + ".");
            });
            s_c.addEventListener(ProgressEvent.SOCKET_DATA, function (e:ProgressEvent):void {
                var bytes:ByteArray = new ByteArray();
                s_c.readBytes(bytes, 0, e.bytesLoaded);
                puts("Client: read " + bytes.length + ".");
                s_t.writeBytes(bytes);
            });

            puts("Tor: connecting to " + tor_address + ":" + tor_port + ".");
            s_t.connect(tor_address, tor_port);
            puts("Client: connecting to " + client_address + ":" + client_port + ".");
            s_c.connect(client_address, client_port);
        }
    }
}
