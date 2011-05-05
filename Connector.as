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
    
    import RTMFPRelay;
    import RTMFPRelayReactor;
    import Utils;
    
    public class Connector extends Sprite implements RTMFPRelayReactor {
      
      /* David's relay (nickname 3VXRyxz67OeRoqHn) that also serves a
         crossdomain policy. */
      private const DEFAULT_TOR_ADDR:Object = {
          host: "173.255.221.44",
          port: 9001
      };
      
      private var output_text:TextField;

      // Socket to Tor relay.
      private var s_t:Socket;
      // Socket to facilitator.
      private var s_f:Socket;
      // RTMFP data relay
      private var relay:RTMFPRelay;
      
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
      
      private function facilitator_is(host:String, port:int):void
      {
        if (s_f != null && s_f.connected) {
          puts("Error: already connected to Facilitator!");
          return;
        }
        
        s_f = new Socket();
        
        s_f.addEventListener(Event.CONNECT, function (e:Event):void {
          puts("Facilitator: connected.");
          onConnectionEvent();
        });
        s_f.addEventListener(Event.CLOSE, function (e:Event):void {
          puts("Facilitator: closed connection.");
        });
        s_f.addEventListener(IOErrorEvent.IO_ERROR, function (e:IOErrorEvent):void {
          puts("Facilitator: I/O error: " + e.text + ".");
        });
        s_f.addEventListener(SecurityErrorEvent.SECURITY_ERROR, function (e:SecurityErrorEvent):void {
          puts("Facilitator: security error: " + e.text + ".");
        });

        puts("Facilitator: connecting to " + host + ":" + port + ".");
        s_f.connect(host, port);
      }
      
      private function tor_relay_is(host:String, port:int):void
      {
        if (s_t != null && s_t.connected) {
          puts("Error: already connected to Tor relay!");
          return;
        }
        
        s_t = new Socket();

        s_t.addEventListener(Event.CONNECT, function (e:Event):void {
          puts("Tor: connected.");
          onConnectionEvent();
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

        puts("Tor: connecting to " + host + ":" + port + ".");
        s_t.connect(host, port);
      }

      private function puts(s:String):void
      {
          output_text.appendText(s + "\n");
          output_text.scrollV = output_text.maxScrollV;
      }
      
      private function loaderinfo_complete(e:Event):void
      {
        var fac_spec:String;
        var tor_spec:String;

        puts("Parameters loaded.");
        
        fac_spec = this.loaderInfo.parameters["facilitator"];
        if (!fac_spec) {
            puts("Error: no \"facilitator\" specification provided.");
            return;
        }
        puts("Facilitator spec: \"" + fac_spec + "\"");
        fac_addr = Utils.parse_addr_spec(fac_spec);
        if (!fac_addr) {
            puts("Error: Facilitator spec must be in the form \"host:port\".");
            return;
        }

        relay = new RTMFPRelay(this);

        tor_addr = DEFAULT_TOR_ADDR;
        tor_relay_is(tor_addr.host, tor_addr.port);
        facilitator_is(fac_addr.host, fac_addr.port);
      }
      
      public function onConnectionEvent():void
      {
        if (s_f != null && s_f.connected && s_t != null && s_t.connected && 
            relay != null && relay.connected) {
              s_f.writeUTFBytes("POST / HTTP/1.1\r\n\r\nclient=%3A"+ relay.cirrus_id + "\r\n");
        }
      }
      
      public function onIOErrorEvent(event:IOErrorEvent):void
      {
        puts("Cirrus: I/O error: " + event.text + ".");
      }
      
      public function onNetStatusEvent(event:NetStatusEvent):void
      {
        switch (event.info.code) {
  				case "NetConnection.Connect.Success" :
  					puts("Cirrus: connected with ID " + relay.cirrus_id + ".");
  					onConnectionEvent();
  					break;
  				case "NetStream.Connect.Success" :
  				  puts("Peer: connected.");
  					break;
  				case "NetStream.Publish.BadName" :
  					puts(event.info.code);
  					break;
  				case "NetStream.Connect.Closed" :
  					puts(event.info.code);
  					break;
  			}
      }
      
      public function onSecurityErrorEvent(event:SecurityErrorEvent):void
      {
        puts("Cirrus: security error: " + event.text + ".");
      }
  }
}
    