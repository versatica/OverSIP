# TODO: Not terimnated yet.

module OverSIP::MI

  class JsonRpcReactor < ::EM::Connection

    include ::OverSIP::LogClient
    include ::OverSIP::Fatal
    
    ERROR_INVALID_JSON      = { :code => -32700, :message => "invalid JSON" }
    ERROR_INVALID_REQUEST   = { :code => -32600, :message => "not a valid request object" }
    ERROR_METHOD_NOT_FOUND  = { :code => -32601, :message => "method does not exist / is not available" }
    ERROR_INVALID_PARAMS    = { :code => -32602, :message => "invalid method parameter(s)" }
    ERROR_INTERNAL          = { :code => -32603, :message => "internal error" }

    # Max size (bytes) of the buffered data when receiving the JSON data.
    # (avoid DoS attacks).
    JSON_MAX_SIZE = 65536

    def initialize(transport)
      super
      case @transport = transport
      when :tcp
        @log_id = "#{self.class.name} TCP #{SecureRandom.hex 4}"
      when :unix
        @log_id = "#{self.class.name} UNIX #{SecureRandom.hex 4}"
      end
      # NOTE: By setting :symbolize_keys => true JSON parsed keys would be converted
      # into Ruby Symbols (which are never GC'd). This could be a risk, but we assume
      # just trusted clients would use this MI mechanism.
      @parser = ::Yajl::Parser.new(:symbolize_keys => true)
      @parser.on_parse_complete = method(:data_parsed)
      @encoder = ::Yajl::Encoder.new
      @state = :init
    end

    def post_init
      case @transport
      when :tcp
        @source_port, @source_ip = ::Socket.unpack_sockaddr_in(get_peername) rescue nil
        log_debug "connection from #{@source_ip}:#{@source_port}"
      when :unix
        log_debug "connection"
      end
    end

    def unbind
      case @transport
      when :tcp
        log_debug "disconnection from #{@source_ip}:#{@source_port}"
      when :unix
        log_debug "disconnection"
      end
    end

    def receive_data(data)
      log_debug "received data: <#{data}>"
      begin
        while case @state
          when :init
            @data_size = 0
            @state = :data
          when :data
            parse_data(data)
            false
          when :ignore
            false
          end
        end

      rescue => e
        fatal e
      end
    end

    def parse_data(data)
      if (@data_size += data.bytesize) > JSON_MAX_SIZE
        log_warn "DoS attack detected: JSON size exceedes #{JSON_MAX_SIZE} bytes, closing connection"
        close_connection
        # After closing client connection some data can still arrrive to "receive_data()"
        # (explained in EM documentation). By setting @state = :ignore we ensure such
        # remaining data is not processed.
        @state = :ignore
        return false
      end

      begin
        @parser << data
        log_notice "*** after @parser << data"
      rescue ::Yajl::ParseError => e
        log_error "parsing error"
        reply_error ERROR_INVALID_JSON, nil
        close_connection_after_writing
        @state = :ignore
      end
    end

    def data_parsed(json)
      case json
      # Individual request.
      when Hash
        process_request(json) if check_request(json)
      # Batch: multiple requests in an array.
      when Array
        EM::Iterator.new(json).each do |request, iter|
          process_request(request) if check_request(request)
          iter.next
        end
      end
    end

    def check_request(request)
      unless request[:jsonrpc] == "2.0"
        description = "doesn't include \"jsonrpc\": \"2.0\""
        log_error "invalid request: #{description}"
        reply_error ERROR_INVALID_REQUEST, request[:id], description
        return false
      end

      unless request[:id]
        description = "doesn't include \"id\" (notifications not allowed)"
        log_error "invalid request: #{description}"
        reply_error ERROR_INVALID_REQUEST, nil, description
        return false
      end

      unless request[:method]
        description = "doesn't include \"method\" key"
        log_error "invalid request: #{description}"
        reply_error ERROR_INVALID_REQUEST, request[:id], description
        return false
      end

      if (params = request[:params])
        unless params.is_a? Array or params.is_a? Hash
          description = "\"params\" must be an array or an object"
          log_error "invalid request: #{description}"
          reply_error ERROR_INVALID_REQUEST, request[:id], description
          return false
        end
      end

      return true
    end

    def process_request(request)
      log_debug "*** process_request()"
      result = {
        "jsonrpc" => "2.0",
        "id" => request[:id],
        "result" => {
          "method" => request[:method],
          "output" => "oh yeah #{SecureRandom.hex 4}"
        }
      }

      reply result, request[:id]
    end

    def reply(result, id)
      response = {
        "jsonrpc" => "2.0",
        "id" => id,
        "result" => result
      }

      # Send the response in chunks (good in case of a big response).
      ### TODO: ¿Poner un rescue por si falla?
      @encoder.encode(response) do |chunk|
        send_data(chunk)
      end
    end
    
    def reply_error(error, id, description=nil)
      if description
        message = "#{error[:message]}: #{description}"
      else
        message = error[:message]
      end
      
      error_response = {
        "jsonrpc" => "2.0",
        "id" => id,
        "error" => {
          "code" => error[:code],
          "message" => message
        }
      }
      
      send_data @encoder.encode(error_response)
    end
     
  end  # class JsonRpcReactor

end

