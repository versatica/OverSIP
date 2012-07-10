module EventMachine

  # Fast method for setting an outgoing TCP connection.
  def self.oversip_connect_tcp_server bind_addr, server, port, klass, *args
    s = bind_connect_server bind_addr, 0, server, port
    c = klass.new s, *args
    @conns[s] = c
    block_given? and yield c
    c
  end


  class Connection

    # We require Ruby 1.9 so don't check String#bytesize method.
    def send_data data
      ::EventMachine::send_data @signature, data, data.bytesize
    end

    def send_datagram data, address, port
      ::EventMachine::send_datagram @signature, data, data.bytesize, address, port
    end

    # Rewrite close_connection so it set an internal attribute (which can be
    # inspected when unbind() callback is called).
    alias _em_close_connection close_connection
    def close_connection after_writing=false
      @local_closed = true
      _em_close_connection after_writing
    end

    def close_connection_after_writing
      close_connection true
    end

  end

end