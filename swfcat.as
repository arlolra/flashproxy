package
{
    import flash.display.Sprite;
    import flash.text.TextField;
    import flash.net.Socket;
    import flash.events.Event;
    import flash.events.IOErrorEvent;
    import flash.events.SecurityErrorEvent;

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

            var s:Socket = new Socket();
            s.addEventListener(Event.CONNECT, function (e:Event):void {
                puts("Connected.");
            });
            s.addEventListener(Event.CLOSE, function (e:Event):void {
                puts("Closed.");
            });
            s.addEventListener(IOErrorEvent.IO_ERROR, function (e:IOErrorEvent):void {
                puts("IO error: " + e.text + ".");
            });
            s.addEventListener(SecurityErrorEvent.SECURITY_ERROR, function (e:SecurityErrorEvent):void {
                puts("Security error: " + e.text + ".");
            });
            puts("Requesting connection.");
            s.connect("192.168.0.2", 9999);
            puts("Connection requested.");
        }
    }
}
