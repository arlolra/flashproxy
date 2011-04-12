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

            var s1:Socket = new Socket();
            var s2:Socket = new Socket();

            s1.addEventListener(Event.CONNECT, function (e:Event):void {
                puts("s1 Connected.");
            });
            s1.addEventListener(Event.CLOSE, function (e:Event):void {
                puts("s1 Closed.");
            });
            s1.addEventListener(IOErrorEvent.IO_ERROR, function (e:IOErrorEvent):void {
                puts("s1 IO error: " + e.text + ".");
            });
            s1.addEventListener(SecurityErrorEvent.SECURITY_ERROR, function (e:SecurityErrorEvent):void {
                puts("s1 Security error: " + e.text + ".");
            });
            s1.addEventListener(ProgressEvent.SOCKET_DATA, function (e:ProgressEvent):void {
                var bytes:ByteArray;
                puts("s1 progress: " + e.bytesLoaded + ".");
                s1.readBytes(bytes, 0, e.bytesLoaded);
                s2.writeBytes(bytes);
            });

            s2.addEventListener(Event.CONNECT, function (e:Event):void {
                puts("s2 Connected.");
            });
            s2.addEventListener(Event.CLOSE, function (e:Event):void {
                puts("s2 Closed.");
            });
            s2.addEventListener(IOErrorEvent.IO_ERROR, function (e:IOErrorEvent):void {
                puts("s2 IO error: " + e.text + ".");
            });
            s2.addEventListener(SecurityErrorEvent.SECURITY_ERROR, function (e:SecurityErrorEvent):void {
                puts("s2 Security error: " + e.text + ".");
            });
            s2.addEventListener(ProgressEvent.SOCKET_DATA, function (e:ProgressEvent):void {
                var bytes:ByteArray;
                puts("s2 progress: " + e.bytesLoaded + ".");
                s2.readBytes(bytes, 0, e.bytesLoaded);
                s1.writeBytes(bytes);
            });

            puts("Requesting connection.");

            s1.connect("10.32.16.133", 9998);
            s2.connect("10.32.16.133", 9999);

            puts("Connection requested.");
        }
    }
}
