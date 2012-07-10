module OverSIP::SIP

  class Logic

    include ::OverSIP::Logger

    def initialize request
      @log_id = "Logic " << request.via_branch_id
      @request = request
    end

  end  # class Logic

end
