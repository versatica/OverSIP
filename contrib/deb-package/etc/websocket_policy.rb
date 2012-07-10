#
# OverSIP - WebSocket Access Policy
#
#
# Fill these functions with your own access policy for allowing or
# disallowing WebSocket connections from clients.
#
# If any of the following methods return _false_ then the WebSocket
# connection is rejected.


module OverSIP::WebSocket::Policy

  # Check the value of the Host header, by splitting it into
  # host (a String) and port (Fixnum). Both could be _nil_.
  def check_hostport host=nil, port=nil
    return true
  end

  # Check the value of the Origin header (a String with original value).
  def check_origin origin=nil
    return true
  end

  # Check the request URI path (String) and query (String). Both can be _nil_.
  def check_request_uri path=nil, query=nil
    return true
  end

end

