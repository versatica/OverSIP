module OverSIP::SIP

  class TcpClient < TcpConnection

    attr_reader :connected
    attr_reader :pending_client_transactions

    def initialize ip, port
      # NOTE: The parent class implementing "initialize" method is Connection, and allows no arguments.
      # If we call just "super" from here it will fail since "ip" and "port" will be passed as
      # arguments. So we must use "super()" and we are done (no arguments are passed to parent).
      super()

      @remote_ip = ip
      @remote_port = port
      @connection_id = ::OverSIP::SIP::TransportManager.add_connection self, self.class, self.class.ip_type, @remote_ip, @remote_port
      @connected = false
      @pending_client_transactions = []

      ### TODO: make it configurable.
      set_pending_connect_timeout 2.0
    end


    def connection_completed
      log_system_info "TCP connection opened to " << remote_desc

      @connected = true
      @pending_client_transactions.clear
    end


    def remote_desc
      @remote_desc ||= case self.class.ip_type
        when :ipv4  ; "#{@remote_ip}:#{@remote_port.to_s}"
        when :ipv6  ; "[#{@remote_ip}]:#{@remote_port.to_s}"
        end
    end


    def unbind cause=nil
      @state = :ignore

      # Remove the connection.
      self.class.connections.delete @connection_id

      @local_closed = true  if cause == ::Errno::ETIMEDOUT

      if @connected
        log_msg = "connection to #{remote_desc} "
        log_msg << ( @local_closed ? "locally closed" : "remotely closed" )
        log_msg << " (cause: #{cause.inspect})"  if cause
        log_system_debug log_msg  if $oversip_debug

      # If the TCP client connection has failed (remote server rejected the connection) then
      # inform to all the pending client transactions.
      else
        log_system_notice "connection to #{remote_desc} failed"  if $oversip_debug

        @pending_client_transactions.each do |client_transaction|
          client_transaction.connection_failed
        end
        @pending_client_transactions.clear
      end unless $!

      @connected = false
    end

  end

end
