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
    
    import Utils;

    public class RTMFPRelay extends Sprite
    {
		    private static const CIRRUS_ADDRESS:String = "rtmfp://p2p.rtmfp.net";
		    private static const CIRRUS_DEV_KEY:String = RTMFP::CIRRUS_KEY;
		
        /* The name of the "media" to pass between peers */
        public static const DATA:String = "data";
		
        protected var output_text:TextField;

        // Socket to Tor relay.
        private var s_t:Socket;
        // Socket to facilitator.
        private var s_f:Socket;

        /* Connection to the Cirrus rendezvous service */
        private var cirrus_conn:NetConnection;
		
		    /* ID of the peer to connect to */
		    private var peer_id:String;
		
		    /* Data streams to be established with peer */
		    private var send_stream:NetStream;
		    private var recv_stream:NetStream;

        private var fac_addr:Object;
        private var tor_addr:Object;

        private function puts(s:String):void
        {
            output_text.appendText(s + "\n");
            output_text.scrollV = output_text.maxScrollV;
        }

        public function RTMFPRelay()
        {
            output_text = new TextField();
            output_text.width = 400;
            output_text.height = 300;
            output_text.background = true;
            output_text.backgroundColor = 0x001f0f;
            output_text.textColor = 0x44CC44;
            addChild(output_text);

            puts("Starting.");
            
            cirrus_conn = new NetConnection();
			      cirrus_conn.addEventListener(NetStatusEvent.NET_STATUS, function (e:NetStatusEvent):void {
			        puts("Cirrus: connected.");
			      });
			      cirrus_conn.addEventListener(IOErrorEvent.IO_ERROR, function (e:IOErrorEvent):void {
				      puts("Cirrus: I/O error: " + e.text + ".");
			      });
			
			      cirrus_conn.addEventListener(SecurityErrorEvent.SECURITY_ERROR, function (e:SecurityError):void {
				      puts("Cirrus: security error: " + e.text + ".");
			      });
			
			      cirrus_conn.connect(CIRRUS_ADDRESS + "/" + CIRRUS_DEV_KEY);
            
            
            // Wait until the query string parameters are loaded.
            this.loaderInfo.addEventListener(Event.COMPLETE, loaderinfo_complete);
        }

        public function data_is(data:ByteArray):void
        {
          
          
        }
        
        public function facilitator_is(host:String, port:String):void
        {
          if (s_f != null && s_f.connected) {
            
            return;
          }
          
          s_f = new Socket();
          
          s_f.addEventListener(Event.CONNECT, function (e:Event):void {
            puts("Facilitator: connected.");
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
        
        public function peer(peer_id:String):String
        {
          return this.peer_id;
        }

        public function peer_is(peer_id:String):void
        {
          if (peer_id == null) {
    				puts("Error: Client ID doesn't exist.");
    				return;
    			} else if (peer_id == cirrus_conn.nearID) {
    				puts("Error: Client ID is our ID.");
    				return;
    			} else if (this.peer_id == peer_id) {
    			  
    			} else if (this.recv_stream != null) {
            puts("Error: already set up with a peer!");
            return;
          }
          
          this.peer_id = peer_id;
          
          send_stream = new NetStream(cirrus_conn, NetStream.DIRECT_CONNECTIONS);
    			send_stream.addEventListener(NetStatusEvent.NET_STATUS, net_status_event_handler);
    			send_stream.publish(DATA);

    			recv_stream = new NetStream(cirrus_conn, peer_id);
    			recv_stream.addEventListener(NetStatusEvent.NET_STATUS, net_status_event_handler);
    			recv_stream.play(DATA);
        }
        
        public function tor_relay_is(host:String, port:String):void
        {
          if (s_t != null && s_t.connected) {
            puts("Error: already connected to Tor relay!");
            return;
          }
          
          s_t = new Socket();

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

          puts("Tor: connecting to " + host + ":" + port + ".");
          s_t.connect(host, port);
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
            fac_addr = parse_addr_spec(fac_spec);
            if (!fac_addr) {
                puts("Error: Facilitator spec must be in the form \"host:port\".");
                return;
            }

            tor_addr = DEFAULT_TOR_ADDR;

            go();
        }

        private function fac_connected(e:Event):void
        {
            

            s_f.addEventListener(ProgressEvent.SOCKET_DATA, function (e:ProgressEvent):void {
              var client_spec:String;
              var client_addr:Object;

              client_spec = s_f.readMultiByte(e.bytesLoaded, "utf-8");
              puts("Facilitator: got \"" + client_spec + "\"");

              /*client_addr = parse_addr_spec(client_spec);
              if (!client_addr) {
                puts("Error: Client spec must be in the form \"host:port\".");
                return;
              }
              if (client_addr.host == "0.0.0.0" && client_addr.port == 0) {
                puts("Error: Facilitator has no clients.");
                return;
              }*/

				      /* Now we have a client, so start up a connection to the Cirrus rendezvous point */
				      
            });

            s_f.writeUTFBytes("GET / HTTP/1.0\r\n\r\n");
        }
		
		private function net_status_event_handler(e:NetStatusEvent):void
		{
			switch (e.info.code) {
				case "NetConnection.Connect.Success" :
					// Cirrus is now connected
					cirrus_connected(e);
			}
			
		}
		
		private function cirrus_connected(e:Event):void
		{
			
					
			
		}

        /*private function client_connected(e:Event):void
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
        }*/
		
		private function close_connections():void
		{
			if (s_t.connected) s_t.close();
			if (s_f.connected) s_f.close();
			if (cirrus.connected) cirrus.close();
			if (send_stream != null) send_stream.close();
			if (recv_stream != null) recv_stream.close();
		}

        
    }
}
