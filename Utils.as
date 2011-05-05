package {
  
  public class Utils {
    
    /* Parse an address in the form "host:port". Returns an Object with
       keys "host" (String) and "port" (int). Returns null on error. */
    public static function parse_addr_spec(spec:String):Object
    {
        var parts:Array;
        var addr:Object;

        parts = spec.split(":", 2);
        if (parts.length != 2 || !parseInt(parts[1]))
            return null;
        addr = {}
        addr.host = parts[0];
        addr.port = parseInt(parts[1]);

        return addr;
    }
    
  }
  
}