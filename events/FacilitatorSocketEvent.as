package events
{
    import flash.events.Event;

    public class FacilitatorSocketEvent extends Event
    {
        public static const CONNECT_CLOSED:String        = "connectClosed";
        public static const CONNECT_FAILED:String        = "connectFailed";
        public static const CONNECT_SUCCESS:String       = "connectSuccess";
        public static const REGISTRATION_RECEIVED:String = "registrationReceived";
        public static const REGISTRATION_FAILED:String   = "registrationFailed";
        public static const REGISTRATIONS_EMPTY:String   = "registrationsEmpty";
        
        public var client:String;

        public function FacilitatorSocketEvent(type:String, client:String = null, bubbles:Boolean = false, cancelable:Boolean = false)
        {
            super(type, bubbles, cancelable);
            this.client = client;
        }
    }
}
