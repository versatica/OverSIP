module OverSIP::SIP

  class UacRequest

    DEFAULT_MAX_FORWARDS = "20"
    DEFAULT_FROM = "\"OverSIP #{::OverSIP::VERSION}\" <sip:uac@oversip.net>"

    attr_reader :sip_method, :ruri, :from, :from_tag, :to, :body, :call_id, :cseq
    attr_reader :antiloop_id
    attr_reader :routes  # Always nil (needed for OverSIP::SIP::Tags.create_antiloop_id().
    attr_accessor :tvars  # Transaction variables (a hash).


    def initialize data, extra_headers=[], body=nil
      unless (@sip_method = data[:sip_method])
        raise ::OverSIP::RuntimeError, "no data[:sip_method] given"
      end
      unless (@ruri = data[:ruri])
        raise ::OverSIP::RuntimeError, "no data[:ruri] given"
      end

      @from = data[:from] || DEFAULT_FROM
      @from_tag = data[:from_tag] || ::SecureRandom.hex(4)
      @to = data[:to] || @ruri
      @call_id = data[:call_id] || ::SecureRandom.hex(8)
      @cseq = data[:cseq] || rand(1000)
      @max_forwards = data[:max_forwards] || DEFAULT_MAX_FORWARDS

      @headers = {}
      @extra_headers = extra_headers

      @body = body

      @antiloop_id = ::OverSIP::SIP::Tags.create_antiloop_id(self)
    end


    def insert_header name, value
      @headers[name] = value.to_s
    end


    def delete_header_top name
      @headers.delete name
    end


    def to_s
      # Let @ruri to be an String, an OverSIP::SIP::Uri or an OverSIP::SIP::NameAddr instance.
      ruri = case @ruri
        when ::String
          @ruri
        when ::OverSIP::SIP::Uri, ::OverSIP::SIP::NameAddr
          @ruri.uri
        end

      msg = "#{@sip_method.to_s} #{ruri} SIP/2.0\r\n"

      @headers.each do |name, value|
        msg << name << ": #{value}\r\n"
      end

      msg << "From: #{@from.to_s};tag=#{@from_tag}\r\n"
      msg << "To: #{@to.to_s}\r\n"
      msg << "Call-ID: #{@call_id}\r\n"
      msg << "CSeq: #{@cseq.to_s} #{@sip_method.to_s}\r\n"
      msg << "Content-Length: #{@body ? @body.bytesize : "0"}\r\n"
      msg << "Max-Forwards: #{@max_forwards.to_s}\r\n"
      msg << HDR_USER_AGENT << CRLF

      @extra_headers.each do |header|
        msg << header << CRLF
      end

      msg << CRLF
      msg << @body  if @body
      msg
    end

  end  # class Request

end
