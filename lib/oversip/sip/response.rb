module OverSIP::SIP

  class Response < Message

    attr_accessor :status_code
    attr_accessor :reason_phrase
    attr_accessor :request  # The associated request.


    def request?      ; false        end
    def response?     ; true         end


    def to_s
      msg = "SIP/2.0 #{@status_code} #{@reason_phrase}\r\n"

      @headers.each do |key, values|
        values.each do |value|
          msg << key << ": #{value}\r\n"
        end
      end

      msg << CRLF
      msg << @body  if @body
      msg
    end

  end  # class Response

end
