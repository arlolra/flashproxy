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
    import flash.utils.ByteArray;
    
    import rtmfp.RTMFPSocket;
    import rtmfp.events.RTMFPSocketEvent;
    import Utils;
    
    public class Connector extends Sprite {
      
      /* David's relay (nickname 3VXRyxz67OeRoqHn) that also serves a
         crossdomain policy. */
      private const DEFAULT_TOR_RELAY:Object = {
          host: "173.255.221.44",
          port: 9001
      };
      
      private var output_text:TextField;
      
      private var s_f:Socket;
      private var s_r:RTMFPSocket;
      private var s_t:Socket;
      
      private var fac_addr:Object;
      private var tor_addr:Object;
      
      public function Connector()
      {
        output_text = new TextField();
        output_text.width = 400;
        output_text.height = 300;
        output_text.background = true;
        output_text.backgroundColor = 0x001f0f;
        output_text.textColor = 0x44CC44;
        addChild(output_text);

        puts("Starting.");
        
        this.loaderInfo.addEventListener(Event.COMPLETE, onLoaderInfoComplete);
      }
      
      protected function puts(s:String):void
      {
          output_text.appendText(s + "\n");
          output_text.scrollV = output_text.maxScrollV;
      }
      
      private function onLoaderInfoComplete(e:Event):void
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
        fac_addr = Utils.parseAddrSpec(fac_spec);
        if (!fac_addr) {
            puts("Error: Facilitator spec must be in the form \"host:port\".");
            return;
        }
        
        tor_spec = this.loaderInfo.parameters["tor"];
        if (!tor_spec) {
          puts("Error: No Tor specification provided.");
          return;
        }
        puts("Tor spec: \"" + tor_spec + "\"")
        tor_addr = Utils.parseAddrSpec(tor_spec);
        if (!tor_addr) {
          puts("Error: Tor spec must be in the form \"host:port\".");
          return;
        }
        
        s_r = new RTMFPSocket();
        s_r.addEventListener(RTMFPSocketEvent.CONNECT_SUCCESS, onRTMFPSocketConnect);
        s_r.addEventListener(RTMFPSocketEvent.CONNECT_FAIL, function (e:Event):void {
          puts("Error: failed to connect to Cirrus.");
        });
        s_r.addEventListener(RTMFPSocketEvent.PUBLISH_START, function(e:RTMFPSocketEvent):void {
          
        });
        s_r.addEventListener(RTMFPSocketEvent.PEER_CONNECTED, function(e:RTMFPSocketEvent):void {
          
        });
        s_r.addEventListener(RTMFPSocketEvent.PEER_DISCONNECTED, function(e:RTMFPSocketEvent):void {
          
        });
        s_r.addEventListener(RTMFPSocketEvent.PEERING_SUCCESS, function(e:RTMFPSocketEvent):void {
          
        });
        s_r.addEventListener(RTMFPSocketEvent.PEERING_FAIL, function(e:RTMFPSocketEvent):void {
          
        });
        s_r.addEventListener(ProgressEvent.SOCKET_DATA, function (e:ProgressEvent):void {
          var bytes:ByteArray = new ByteArray();
          s_r.readBytes(bytes);
          puts("RTMFP: read " + bytes.length + " bytes.");
          s_t.writeBytes(bytes);
        });
        
        s_r.connect();
      }
      
      private function onRTMFPSocketConnect(event:RTMFPSocketEvent):void
      {
        puts("Cirrus: connected with id " + s_r.id + ".");
        s_t = new Socket();
        s_t.addEventListener(Event.CONNECT, onTorSocketConnect);
        s_t.addEventListener(Event.CLOSE, function (e:Event):void {
          
        });
        s_t.addEventListener(IOErrorEvent.IO_ERROR, function (e:IOErrorEvent):void {
          puts("Tor: I/O error: " + e.text + ".");
        });
        s_t.addEventListener(ProgressEvent.SOCKET_DATA, function (e:ProgressEvent):void {
          var bytes:ByteArray = new ByteArray();
          s_t.readBytes(bytes, 0, e.bytesLoaded);
          puts("Tor: read " + bytes.length + " bytes.");
          s_r.writeBytes(bytes);
        });
        s_t.addEventListener(SecurityErrorEvent.SECURITY_ERROR, function (e:SecurityErrorEvent):void {
          puts("Tor: security error: " + e.text + ".");
        });

        s_t.connect(tor_addr.host, tor_addr.port);
        onTorSocketConnect(new Event(""));
      }
      
      private function onTorSocketConnect(event:Event):void
      {
        puts("Tor: connected to " + tor_addr.host + ":" + tor_addr.port + ".");
        
        s_f = new Socket();
        s_f.addEventListener(Event.CONNECT, onFacilitatorSocketConnect);
        s_f.addEventListener(Event.CLOSE, function (e:Event):void {
          
        });
        s_f.addEventListener(IOErrorEvent.IO_ERROR, function (e:IOErrorEvent):void {
          puts("Facilitator: I/O error: " + e.text + ".");
        });
        s_f.addEventListener(ProgressEvent.SOCKET_DATA, function (e:ProgressEvent):void {
          var clientID:String = s_f.readMultiByte(e.bytesLoaded, "utf-8");
          puts("Facilitator: got \"" + clientID + "\"");
          puts("Connecting to " + clientID + ".");
          s_r.peer = clientID;
        });
        s_f.addEventListener(SecurityErrorEvent.SECURITY_ERROR, function (e:SecurityErrorEvent):void {
          puts("Facilitator: security error: " + e.text + ".");
        });

        s_f.connect(fac_addr.host, fac_addr.port);
      }
      
      private function onFacilitatorSocketConnect(event:Event):void
      {
        puts("Facilitator: connected to " + fac_addr.host + ":" + fac_addr.port + ".");
        onConnectionEvent();
      }
      
      private function onConnectionEvent():void
      {
        if (s_f != null && s_f.connected && s_t != null && /*s_t.connected && */
            s_r != null && s_r.connected) {
              if (this.loaderInfo.parameters["proxy"]) {
                s_f.writeUTFBytes("GET / HTTP/1.0\r\n\r\n");
              } else {
                var str:String = "POST / HTTP/1.0\r\n\r\nclient=" + s_r.id + "\r\n"
                puts(str);
                s_f.writeUTFBytes(str);
              }
        }
      }
  }
}