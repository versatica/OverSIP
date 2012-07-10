module OverSIP::WebSocket

  class WsAutobahnApp < WsApp

    LOG_ID = "WS IPv4 AutoBahn app"
    def log_id
      LOG_ID
    end

    def process_text_message ws_message
      #log_system_info "received WS text message: length=#{ws_message.bytesize}, replying the same..."
      @ws_framing.send_text_frame ws_message
    end


    def process_binary_message ws_message
      #log_system_info "received WS binary message: length=#{ws_message.bytesize}, replying the same..."
      @ws_framing.send_binary_frame ws_message
    end

  end  # WsAutobahnApp

end
