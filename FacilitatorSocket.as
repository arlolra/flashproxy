package
{
    import flash.events.Event;
    import flash.events.EventDispatcher;
    import flash.events.HTTPStatusEvent;
    import flash.events.IOErrorEvent;
    import flash.events.SecurityErrorEvent;
    import flash.net.URLLoader;
    import flash.net.URLLoaderDataFormat;
    import flash.net.URLRequest;
    import flash.net.URLRequestMethod;
    import flash.net.URLVariables;
    
    import events.FacilitatorSocketEvent;
    
    [Event(name=FacilitatorSocketEvent.CONNECT_FAILED, type="com.flashproxy.rtmfp.events.FacilitatorSocketEvent")]
    [Event(name=FacilitatorSocketEvent.REGISTRATION_FAILED, type="com.flashproxy.rtmfp.events.FacilitatorSocketEvent")]
    [Event(name=FacilitatorSocketEvent.REGISTRATION_RECEIVED, type="com.flashproxy.rtmfp.events.FacilitatorSocketEvent")]
    [Event(name=FacilitatorSocketEvent.REGISTRATIONS_EMPTY, type="com.flashproxy.rtmfp.events.FacilitatorSocketEvent")]
    public class FacilitatorSocket extends EventDispatcher
    {
        private var host:String;
        private var port:uint;
        
        public function FacilitatorSocket(host:String, port:uint)
        {   
            this.host = host;
            this.port = port; 
        }
        
        public function get_registration():void
        {
            make_request(URLRequestMethod.GET);
        }
        
        public function post_registration(registration_data:String):void
        {    
            var data:URLVariables = new URLVariables();
            data.client = registration_data;
            make_request(URLRequestMethod.POST, data);
        }
        
        private function fail():void
        {
            dispatchEvent(new FacilitatorSocketEvent(FacilitatorSocketEvent.CONNECT_FAILED));
        }
        
        private function make_request(method:String, data:URLVariables = null):void
        {
            var request:URLRequest;
            var loader:URLLoader;

            loader = new URLLoader();
            /* Get the x-www-form-encoded-values. */
            loader.dataFormat = URLLoaderDataFormat.VARIABLES;
            loader.addEventListener(Event.COMPLETE, on_complete_event);
            loader.addEventListener(SecurityErrorEvent.SECURITY_ERROR, on_security_error_event);
            loader.addEventListener(IOErrorEvent.IO_ERROR, on_io_error_event);

            request = new URLRequest(url);
            request.data = data;
            request.method = method;
            loader.load(request);
        }
        
        private function on_complete_event(event:Event):void
        {
            try {
                var client_id:String = event.target.data.client;
                var relay_addr:String = event.target.data.relay;
                if (client_id == "") {
                    dispatchEvent(new FacilitatorSocketEvent(FacilitatorSocketEvent.REGISTRATIONS_EMPTY));
                } else {
                    dispatchEvent(new FacilitatorSocketEvent(FacilitatorSocketEvent.REGISTRATION_RECEIVED, client_id, relay_addr));
                }
            } catch (e:Error) {
                /* error is thrown for POST when we don't care about
                   the response anyways */
            }
            
            event.target.close()
        }
        
        private function on_io_error_event(event:IOErrorEvent):void
        {
            fail();
        }

        private function on_security_error_event(event:SecurityErrorEvent):void
        {
            fail();
        }
        
        private function get url():String
        {
            return "http://" + encodeURIComponent(host)
                + ":" + encodeURIComponent(port.toString()) + "/";
        }
    }
}
