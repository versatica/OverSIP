module OverSIP::WebSocket

  class HttpRequest < ::Hash

    include ::OverSIP::Logger

    # HTTP related attributes.
    attr_accessor :transport
    attr_accessor :source_ip
    attr_accessor :source_ip_type
    attr_accessor :source_port
    attr_accessor :connection

    # HTTP request attributes.
    attr_reader :http_method
    attr_reader :http_version
    attr_reader :uri_scheme
    attr_reader :uri
    attr_reader :uri_path
    attr_reader :uri_query
    attr_reader :uri_fragment
    attr_reader :host
    attr_reader :port
    attr_reader :content_length
    attr_reader :hdr_connection
    attr_reader :hdr_upgrade
    attr_reader :hdr_origin
    attr_reader :hdr_sec_websocket_version
    attr_reader :hdr_sec_websocket_key
    attr_reader :hdr_sec_websocket_protocol


    def log_id
      @log_id ||= "HTTP Request #{@connection.connection_log_id}"
    end

    def unknown_method?  ;  @is_unknown_method  end


    def reply status_code, reason_phrase=nil, extra_headers={}
      reason_phrase ||= REASON_PHARSE[status_code] || REASON_PHARSE_NOT_SET
      extra_headers ||= {}

      response = "#{@http_version} #{status_code} #{reason_phrase}\r\n"

      extra_headers.each {|header| response << header << "\r\n"}

      response << HDR_SERVER << "\r\n\r\n"

      log_system_debug "replying #{status_code} \"#{reason_phrase}\""  if $oversip_debug

      if @connection.error?
        log_system_warn "cannot send response, TCP connection is closed"
        return false
      end

      @connection.send_data response
      return true
    end

  end  # class HttpRequest

end
