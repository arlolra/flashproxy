package
{
    import flash.display.Sprite;
    import flash.text.TextField;
    import flash.net.XMLSocket;

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
        }
    }
}
