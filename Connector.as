package
{
    import flash.display.Sprite;
    import flash.text.TextField;
    import flash.net.Socket;
    import flash.events.Event;
    import flash.events.EventDispatcher;
    import flash.events.IOErrorEvent;
    import flash.events.NetStatusEvent;
    import flash.events.ProgressEvent;
    import flash.events.SecurityErrorEvent;
    import flash.net.NetConnection;
    import flash.net.NetStream;
    import flash.utils.ByteArray;
    import flash.utils.clearInterval;
    import flash.utils.setInterval;
    import flash.utils.setTimeout;
    
    public class Connector extends RTMFPRelay {
      
      private var output_text:TextField;
      
      private var fac_addr:Object;
      private var tor_addr:Object;
      
      public function Connector() {
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
        var tor_spec:String;

        puts("Parameters loaded.");
        
        
      }
    
}
    