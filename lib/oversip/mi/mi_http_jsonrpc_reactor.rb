# TODO: Not terimnated yet.

module OverSIP::MI

  class JsonRpcReactor < ::EM::Connection

    include ::OverSIP::LogClient
    include ::OverSIP::Fatal

    # Max size (bytes) of the buffered data when receiving message headers
    # (avoid DoS attacks).
    HEADERS_MAX_SIZE = 65536

    # Log id is class name plus transport type.
    def log_id
      @log_id ||= "MI::#{self.class.name}"
    end

    def initialize
      super
      @parser = ::OverSIP::HTTP::RequestParser.new
      @buffer = ::IO::Buffer.new
      @state = :init
    end

    def post_init
      @source_port, @source_ip = ::Socket.unpack_sockaddr_in(get_peername) rescue nil
      log_debug "connection from #{@source_ip}:#{@source_port}"
    end

    def unbind
      log_debug "disconnection from #{@source_ip}:#{@source_port}"
    end

    def receive_data(data)
      @buffer << data

      begin
        while case @state

          when :init
            @request = ::OverSIP::HTTP::Request.new
            @parser.reset
            @parser_nbytes = 0
            @bytes_remaining = 0
            @state = :headers
          when :headers
            parse_headers
          when :body
            get_body
          when :check_request
            check_request
          when :finished
            do_rpc
            @state = :init
            true
          when :ignore
            false
          ### TODO: Esto no debería pasar nunca así que hay que quitarlo.
          else
            fatal "invalid state :#{@state}"
          end
        end

      rescue => e
        fatal e
      end
    end

    def parse_headers
      return false if @buffer.empty?

      # Avoid flood attacks in TCP (very long headers).
      if @buffer.size > HEADERS_MAX_SIZE
        log_warn "DoS attack detected: headers size exceedes #{HEADERS_MAX_SIZE} bytes, closing  connection with #{@source_ip}:#{@source_port}"
        close_connection
        # After closing client connection some data can still arrrive to "receive_data()"
        # (explained in EM documentation). By setting @state = :ignore we ensure such
        # remaining data is not processed.
        @state = :ignore
        return false
      end

      # Parse the currently buffered data. If parsing fails @parser_nbytes gets nil value.
      unless @parser_nbytes = @parser.execute(@request, @buffer.to_str, @parser_nbytes)
        log_warn "parsing error: \"#{@parser.error}\""
        close_connection_after_writing
        @state = :ignore
        return false
      end

      unless @parser.finished?
        # The parsing has not finished.
        return false
      end

      # Clear parsed data from the buffer.
      @buffer.read(@parser_nbytes)

      # Examine Content-Length header.
      if @body_length = @request.content_length and @body_length > 0
        @state = :body
        return true
      else
        # Set :finished state and return true to process the parsed message.
        @state = :check_request
        return true
      end
    end  # parse_headers

    def get_body
      # Return false until the buffer gets all the body.
      return false if @buffer.size < @body_length

      @request.body = @buffer.read @body_length
      @state = :check_request
      return true
    end
    
    def check_request
      # Must be a POST.
      unless @request.http_method == :POST
        log_warn "Invalid request method: #{@request.http_method} => 400"
        reject 400
        return false
      end

      # Must be "application/json"
      unless @request.content_type == "application/json"
        log_warn "\"Content-Type\" header is not \"application/json\" => 400"
        reject 400
        return false
      end

      @state = :finished
      return true
    end
    
    def do_rpc
      log_info "received a valid RPC request !!!"
      send_data @request.generate_response 202, nil, ["Content-Length: 0"]
      return true
    end


    def reject(status = nil, reason_phrase = nil, extra_headers = nil)
      send_data @request.generate_response(status, reason_phrase, extra_headers) if status
      status ? close_connection_after_writing : close_connection
      @state = :ignore
    end

  end  # class JsonRpcReactor

end

