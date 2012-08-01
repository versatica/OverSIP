#
# OverSIP - Events.
#
#
# OverSIP common callbacks. Fill them according to your needs.


module OverSIP::Events

  extend ::OverSIP::Logger
  @log_id = "Events"

  # This method is called once a WebSocket connection has been accepted
  # but before the HTTP 101 has been replied to the client.
  # Here you can inspect the HTTP request (WebSocket handshake) and,
  # based on your service, reject the connection by calling:
  #
  #   connection.http_reject(status_code, reason_phrase=nil, extra_headers=nil)
  #
  # You can also set variables for this connection via the connection.cvars
  # hash. You can later inspect such a hash within the logic.rb file by
  # accessing to @request.cvars.
  # 
  def self.on_new_websocket_connection connection, http_request
    # Do something.
  end

  # This method is called once a WebSocket connection has been closed.
  #
  def self.on_websocket_connection_closed connection
    # Do something.
  end

end
