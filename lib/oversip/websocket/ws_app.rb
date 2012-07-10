module OverSIP::WebSocket

  class WsApp

    include ::OverSIP::Logger


    def self.class_init
      @@max_message_size = ::OverSIP.configuration[:websocket][:max_ws_message_size]
      @@ws_keepalive_interval = ::OverSIP.configuration[:websocket][:ws_keepalive_interval]
    end


    def initialize connection, ws_framing
      @connection = connection
      @ws_framing = ws_framing
      @ws_message = ::IO::Buffer.new

      # Mantain WebSocket keepalive.
      @ws_framing.do_keep_alive @@ws_keepalive_interval  if @@ws_keepalive_interval
    end


    def close_connection status=nil, reason=nil
      @ws_framing.send_close_frame status, reason
    end


    def receive_payload_data payload_data
      # payload_data is always Encoding::BINARY so also @ws_message.to_str.
      @ws_message << payload_data

      # Check max message size.
      if @ws_message.size > @@max_message_size
        close_connection 1009, "message too big"
        return false
      end
      true
    end


    def message_done type
      log_system_debug "received WS message: length=#{@ws_message.size}"  if $oversip_debug

      case type

      when :text
        ws_message = @ws_message.to_str.force_encoding ::Encoding::UTF_8
        process_text_message ws_message

      when :binary
        process_binary_message @ws_message.to_str  # As IO::Buffer#to_str always generates Encoding::BINARY.
      end

      @ws_message.clear
      true
    end


    def tcp_closed
      nil
    end


    # Methods to be overriden by child classes.
    def process_text_message ws_message
    end

    def process_binary_message ws_message
    end


  end  # WsApplication

end
