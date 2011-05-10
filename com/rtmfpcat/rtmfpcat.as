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
    import flash.utils.setTimeout;
    
    import rtmfp.RTMFPSocket;
    import rtmfp.events.RTMFPSocketEvent;
    import Utils;
    
    public class rtmfpcat extends Sprite {
      
      /* Nate's facilitator -- also serving a crossdomain policy */
      private const DEFAULT_FAC_ADDR:Object = {
        host: "128.12.179.80",
        port: 9002
      };
      
      private const DEFAULT_TOR_CLIENT_ADDR:Object = {
        host: "127.0.0.1",
        port: 3333
      };
      
      /* David's bridge (nickname eRYaZuvY02FpExln) that also serves a
         crossdomain policy. */
      private const DEFAULT_TOR_PROXY_ADDR:Object = {
        host: "69.164.193.231",
        port: 9001
      };
      
      // Milliseconds.
      private const FACILITATOR_POLL_INTERVAL:int = 10000;
      
      private var output_text:TextField;
      
      private var s_f:Socket;
      private var s_r:RTMFPSocket;
      private var s_t:Socket;
      
      private var fac_addr:Object;
      private var tor_addr:Object;
      
      private var proxy_mode:Boolean;
      
      public function rtmfpcat()
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
        
        proxy_mode = (this.loaderInfo.parameters["proxy"] != null);
        
        fac_spec = this.loaderInfo.parameters["facilitator"];
        if (!fac_spec) {
          puts("No \"facilitator\" specification provided...using default.");
          fac_addr = DEFAULT_FAC_ADDR;
        } else {
          puts("Facilitator spec: \"" + fac_spec + "\"");
          fac_addr = Utils.parseAddrSpec(fac_spec);
        }
        
        if (!fac_addr) {
            puts("Error: Facilitator spec must be in the form \"host:port\".");
            return;
        }
        
        tor_spec = this.loaderInfo.parameters["tor"];
        if (!tor_spec) {
          puts("No Tor specification provided...using default.");
          if (proxy_mode) tor_addr = DEFAULT_TOR_PROXY_ADDR;
          else tor_addr = DEFAULT_TOR_CLIENT_ADDR;
        } else {
          puts("Tor spec: \"" + tor_spec + "\"")
          tor_addr = Utils.parseAddrSpec(tor_spec);
        }

        if (!tor_addr) {
          puts("Error: Tor spec must be in the form \"host:port\".");
          return;
        }

        establishRTMFPConnection();
      }
      
      private function establishRTMFPConnection():void
      {
        s_r = new RTMFPSocket();
        s_r.addEventListener(RTMFPSocketEvent.CONNECT_SUCCESS, function (e:Event):void {
          puts("Cirrus: connected with id " + s_r.id + ".");
          establishFacilitatorConnection();
        });
        s_r.addEventListener(RTMFPSocketEvent.CONNECT_FAIL, function (e:Event):void {
          puts("Error: failed to connect to Cirrus.");
        });
        s_r.addEventListener(RTMFPSocketEvent.PUBLISH_START, function(e:RTMFPSocketEvent):void {
          puts("Publishing started.");
        });
        s_r.addEventListener(RTMFPSocketEvent.PEER_CONNECTED, function(e:RTMFPSocketEvent):void {
          puts("Peer connected.");
        });
        s_r.addEventListener(RTMFPSocketEvent.PEER_DISCONNECTED, function(e:RTMFPSocketEvent):void {
          puts("Peer disconnected.");
        });
        s_r.addEventListener(RTMFPSocketEvent.PEERING_SUCCESS, function(e:RTMFPSocketEvent):void {
          puts("Peering success.");
          establishTorConnection();
        });
        s_r.addEventListener(RTMFPSocketEvent.PEERING_FAIL, function(e:RTMFPSocketEvent):void {
          puts("Peering fail.");
        });
        s_r.addEventListener(ProgressEvent.SOCKET_DATA, function (e:ProgressEvent):void {
          var bytes:ByteArray = new ByteArray();
          s_r.readBytes(bytes);
          puts("RTMFP: read " + bytes.length + " bytes.");
          s_t.writeBytes(bytes);
        });
        
        s_r.connect();
      }
      
      private function establishTorConnection():void
      {
        s_t = new Socket();
        s_t.addEventListener(Event.CONNECT, function (e:Event):void {
          puts("Tor: connected to " + tor_addr.host + ":" + tor_addr.port + ".");
        });
        s_t.addEventListener(Event.CLOSE, function (e:Event):void {
          puts("Tor: closed connection.");
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
      }
      
      private function establishFacilitatorConnection():void
      {
        s_f = new Socket();
        s_f.addEventListener(Event.CONNECT, function (e:Event):void {
          puts("Facilitator: connected to " + fac_addr.host + ":" + fac_addr.port + ".");
          if (proxy_mode) s_f.writeUTFBytes("GET / HTTP/1.0\r\n\r\n");
          else s_f.writeUTFBytes("POST / HTTP/1.0\r\n\r\nclient=" + s_r.id + "\r\n");
        });
        s_f.addEventListener(Event.CLOSE, function (e:Event):void {
          puts("Facilitator: connection closed.");
          if (proxy_mode) {
            setTimeout(establishFacilitatorConnection, FACILITATOR_POLL_INTERVAL);
          }
        });
        s_f.addEventListener(IOErrorEvent.IO_ERROR, function (e:IOErrorEvent):void {
          puts("Facilitator: I/O error: " + e.text + ".");
        });
        s_f.addEventListener(ProgressEvent.SOCKET_DATA, function (e:ProgressEvent):void {
          var clientID:String = s_f.readMultiByte(e.bytesLoaded, "utf-8");
          puts("Facilitator: got \"" + clientID + "\"");
          if (clientID != "Registration list empty") {
            puts("Connecting to " + clientID + ".");
            s_r.peer = clientID;
          }
        });
        s_f.addEventListener(SecurityErrorEvent.SECURITY_ERROR, function (e:SecurityErrorEvent):void {
          puts("Facilitator: security error: " + e.text + ".");
        });

        s_f.connect(fac_addr.host, fac_addr.port);
      }
  }
}