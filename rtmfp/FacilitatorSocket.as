package rtmfp
{
    import flash.net.Socket;
    import flash.events.Event;
    import flash.events.EventDispatcher;
    import flash.events.IOErrorEvent;
    import flash.events.NetStatusEvent;
    import flash.events.ProgressEvent;
    import flash.events.SecurityErrorEvent;
    import flash.utils.clearInterval;
    import flash.utils.setInterval;
    
    import rtmfp.events.FacilitatorSocketEvent;
    
    [Event(name=FacilitatorSocketEvent.CONNECT_CLOSED, type="com.flashproxy.rtmfp.events.FacilitatorSocketEvent")]
    [Event(name=FacilitatorSocketEvent.CONNECT_FAILED, type="com.flashproxy.rtmfp.events.FacilitatorSocketEvent")]
    [Event(name=FacilitatorSocketEvent.CONNECT_SUCCESS, type="com.flashproxy.rtmfp.events.FacilitatorSocketEvent")]
    [Event(name=FacilitatorSocketEvent.REGISTRATION_FAILED, type="com.flashproxy.rtmfp.events.FacilitatorSocketEvent")]
    [Event(name=FacilitatorSocketEvent.REGISTRATION_RECEIVED, type="com.flashproxy.rtmfp.events.FacilitatorSocketEvent")]
    [Event(name=FacilitatorSocketEvent.REGISTRATIONS_EMPTY, type="com.flashproxy.rtmfp.events.FacilitatorSocketEvent")]
    public class FacilitatorSocket extends EventDispatcher
    {
        private var socket:Socket;
        private var connected:Boolean;
        private var connection_timeout:uint;
        
        public function FacilitatorSocket()
        {
            socket = null;
            connected = false;
        }
        
        public function close():void
        {
            connected = false;
            if (socket != null) {
                socket.removeEventListener(Event.CONNECT, on_connect_event);
                socket.removeEventListener(Event.CLOSE, on_close_event);
                socket.removeEventListener(IOErrorEvent.IO_ERROR, on_io_error_event);
                socket.removeEventListener(ProgressEvent.SOCKET_DATA, on_progress_event);
                socket.removeEventListener(SecurityErrorEvent.SECURITY_ERROR, on_security_error_event);
                if (connected) {
                    socket.close();
                }
            }
        }
        
        public function connect(host:String, port:uint):void
        {
            if (socket != null || connected) {
                return;
            }
            
            socket = new Socket();
            socket.addEventListener(Event.CONNECT, on_connect_event);
            socket.addEventListener(Event.CLOSE, on_close_event);
            socket.addEventListener(IOErrorEvent.IO_ERROR, on_io_error_event);
            socket.addEventListener(ProgressEvent.SOCKET_DATA, on_progress_event);
            socket.addEventListener(SecurityErrorEvent.SECURITY_ERROR, on_security_error_event);
            socket.connect(host, port);
        }
        
        public function get_registration():void
        {
            if (!connected) return;
            socket.writeUTFBytes("GET / HTTP/1.0\r\n\r\n");
        }
        
        public function post_registration(registration_data:String):void
        {
            if (!connected) return;
            socket.writeUTFBytes("POST / HTTP/1.0\r\n\r\nclient=" + registration_data + "\r\n");
        }
        
        private function fail():void
        {
            clearInterval(connection_timeout);
            dispatchEvent(new FacilitatorSocketEvent(FacilitatorSocketEvent.CONNECT_FAILED));
        }
        
        private function on_close_event(event:Event):void
        {
            close();
            dispatchEvent(new FacilitatorSocketEvent(FacilitatorSocketEvent.CONNECT_CLOSED));
        }
        
        private function on_connect_event(event:Event):void
        {
            connected = true;
            dispatchEvent(new FacilitatorSocketEvent(FacilitatorSocketEvent.CONNECT_SUCCESS));
        }
        
        private function on_io_error_event(event:IOErrorEvent):void
        {
            fail();
        }
        
        private function on_progress_event(event:ProgressEvent):void
        {
            var client_id:String = socket.readUTFBytes(event.bytesLoaded);
            if (client_id == "Registration list empty") {
                dispatchEvent(new FacilitatorSocketEvent(FacilitatorSocketEvent.REGISTRATIONS_EMPTY));
            } else {
                dispatchEvent(new FacilitatorSocketEvent(FacilitatorSocketEvent.REGISTRATION_RECEIVED, client_id));
            }   
        }

        private function on_security_error_event(event:SecurityErrorEvent):void
        {
            fail();
        }
        
        
    }
}