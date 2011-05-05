package {

  import flash.events.IOErrorEvent;
  import flash.events.NetStatusEvent;
  import flash.events.SecurityErrorEvent;
  
  public interface RTMFPRelayReactor {
    function onIOErrorEvent(event:IOErrorEvent):void;
    function onNetStatusEvent(event:NetStatusEvent):void;
    function onSecurityErrorEvent(event:SecurityErrorEvent):void
  }
  
}