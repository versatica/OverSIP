module OverSIP::SIP

  class Uri
    attr_reader :scheme, :user, :host, :host_type, :port, :params, :transport_param, :ovid_param, :phone_context_param, :headers
    attr_accessor :uri_modified

    def scheme= value
      return nil  if unknown_scheme?
      @scheme = value
      @uri_modified = true
    end

    def unknown_scheme?
      not @scheme.is_a? Symbol
    end

    def user= value
      return nil  if unknown_scheme?
      @user = value
      @uri_modified = true
    end
    alias :number :user
    alias :number= :user=

    def host= value
      return nil  if unknown_scheme?
      @host = value
      @host_type = ::OverSIP::Utils.ip_type(value) || :domain
      @uri_modified = true
    end
    alias :domain :host
    alias :domain= :host=

    def host_type= value
      return nil  if unknown_scheme?
      @host_type = value
    end

    def port= value
      return nil  if unknown_scheme?
      @port = value
      @uri_modified = true
    end

    def params
      @params ||= {}
    end

    def set_param k, v
      return nil  if unknown_scheme?
      @params ||= {}
      @params[k.downcase] = v
      @uri_modified = true
    end

    def del_param k
      return nil  if unknown_scheme?
      return false  unless @params
      if @params.include?(k=k.downcase)
        @uri_modified = true
        return @params.delete(k)
      end
      false
    end

    def lr_param?
      @lr_param ? true : false
    end

    def ob_param?
      @ob_param ? true : false
    end

    def headers= value
      return nil  if unknown_scheme?
      @headers = value
      @uri_modified = true
    end

    def uri
      return @uri  unless @uri_modified

      case @scheme
        when :sip, :sips
          @uri = @scheme.to_s << ":"
          ( @uri << ::EscapeUtils.escape_uri(@user) << "@" )  if @user
          @uri << @host
          ( @uri << ":" << @port.to_s )  if @port

          @params.each do |k,v|
            @uri << ";" << k
            ( @uri << "=" << v.to_s )  if v
          end  if @params

          @uri << @headers  if @headers

        when :tel
          @uri = "tel:"
          @uri << @user

          @params.each do |k,v|
            @uri << ";" << k
            ( @uri << "=" << v.to_s )  if v
          end  if @params

        end

      @uri_modified = false
      @uri
    end
    alias :to_s :uri
    alias :inspect :uri

  end  # class Uri

end