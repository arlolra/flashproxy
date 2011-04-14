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

            puts("Tor: connecting.");
            s_t.connect(TOR_ADDRESS, TOR_PORT);
            puts("Client: connecting.");
            s_c.connect(CLIENT_ADDRESS, CLIENT_PORT);
        }
    }
}
