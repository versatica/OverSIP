module OverSIP::WebSocket

  module DefaultPolicy

    def check_hostport host=nil, port=nil
      true
    end

    def check_origin origin=nil
      true
    end

    def check_request_uri path=nil, query=nil
      true
    end

  end

end