module OverSIP::SIP

  class NameAddr < OverSIP::SIP::Uri

    attr_reader :display_name

    def display_name= value
      @display_name = value
      @name_addr_modified = true
    end

    def to_s
      return @name_addr  if @name_addr and not @name_addr_modified and not @uri_modified

      @name_addr = ""
      ( @name_addr << '"' << @display_name << '" ' )  if @display_name
      @name_addr << "<" << uri << ">"

      @name_addr_modified = false
      @name_addr

    end
    alias :inspect :to_s

    def modified?
      @uri_modified or @name_addr_modified
    end

  end

end