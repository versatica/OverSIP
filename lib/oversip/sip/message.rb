module OverSIP::SIP

  class Message

    include ::OverSIP::Logger

    DIALOG_FORMING_METHODS = { :INVITE=>true, :SUBSCRIBE=>true, :REFER=>true }
    RECORD_ROUTING_AWARE_METHODS = { :INVITE=>true, :REGISTER=>true, :SUBSCRIBE=>true, :REFER=>true }
    OUTBOUND_AWARE_METHODS = { :INVITE=>true, :REGISTER=>true, :SUBSCRIBE=>true, :REFER=>true }
    EMPTY_ARRAY = [].freeze

    # SIP related attributes.
    attr_accessor :transport
    attr_accessor :source_ip
    attr_accessor :source_ip_type
    attr_accessor :source_port
    attr_accessor :connection

    # SIP message attributes.
    attr_reader :sip_method
    attr_reader :sip_version
    attr_reader :headers

    attr_reader :via_sent_by_host
    attr_reader :via_sent_by_port
    attr_reader :via_branch
    attr_accessor :via_branch_id  # It's the branch value without "z9hG4bK".
    attr_reader :via_branch_rfc3261
    attr_reader :via_received
    attr_reader :via_has_rport
    attr_accessor :via_rport  # Value not parsed.
    attr_reader :via_has_alias
    attr_reader :via_core_value
    attr_reader :via_params
    attr_reader :num_vias

    attr_reader :call_id
    attr_reader :cseq
    attr_reader :max_forwards
    attr_reader :content_length
    attr_reader :routes
    attr_reader :require
    attr_reader :supported
    attr_reader :proxy_require

    attr_accessor :body

    attr_accessor :from  # NameAddr instance.
    attr_reader :from_tag
    attr_accessor :to  # NameAddr instance.
    attr_reader :to_tag
    attr_reader :contact  # NameAddr instance (when it has a single value).
    attr_reader :contact_params

    attr_reader :hdr_via  # Array
    attr_reader :hdr_from  # String
    attr_reader :hdr_to  # String
    attr_reader :hdr_route  # Array

    # Other attributes.
    attr_accessor :tvars  # Transaction variables (a hash).
    attr_accessor :cvars  # Connection variables (a hash).

    def udp?               ; @transport == :udp          end
    def tcp?               ; @transport == :tcp          end
    def tls?               ; @transport == :tls          end
    def ws?                ; @transport == :ws           end
    def wss?               ; @transport == :wss          end

    def websocket?         ; @transport == :ws || @transport == :wss  end

    def unknown_method?    ; @is_unknown_method          end

    def via_rport?         ; @via_has_rport              end

    def via_alias?         ; @via_has_alias              end

    def dialog_forming?
      DIALOG_FORMING_METHODS[@sip_method]
    end

    def record_routing_aware?
      RECORD_ROUTING_AWARE_METHODS[@sip_method]
    end

    def outbound_aware?
      OUTBOUND_AWARE_METHODS[@sip_method]
    end

    # Returns true if a header with the given header _name_ exists, false otherwise.
    def has_header? name
      @headers[MessageParser.headerize(name)] && true
    end

    # Returns the first value of the given header _name_, nil if it doesn't exist.
    def header_top name
      ( hdr = @headers[MessageParser.headerize(name)] ) ? hdr[0] : nil
    end
    alias :header :header_top

    # Returns an array with all the values of the given header _name_, an empty array
    # if it doesn't exist.
    def header_all name
      ( hdr = @headers[MessageParser.headerize(name)] ) ? hdr : EMPTY_ARRAY
    end

    # Replaces the header of given _name_ with a the given _value_.
    # _value_ can be a single value or an array.
    def set_header name, value
      @headers[MessageParser.headerize(name)] =
        case value
        when Array
          value
        else
          [ value.to_s ]
        end
    end

    # Completely deletes the header with given _name_.
    # Returns an array containing all the header values, nil otherwise.
    def delete_header name
      @headers.delete MessageParser.headerize(name)
    end

    # Removes the first value of a given header _name_.
    # Returns the extracted value, nil otherwise.
    def delete_header_top name
      if hdr = @headers[k=MessageParser.headerize(name)]
        hdr.size > 1 ? hdr.shift : @headers.delete(k)[0]
      end
    end

    # Inserts the given _value_ in the first position of header _name_.
    # _value_ must be a string.
    def insert_header name, value
      if hdr = @headers[k=MessageParser.headerize(name)]
        hdr.insert 0, value.to_s
      else
        #@headers[k] = [ value.to_s ]
        # NOTE: If the header name doesn't already exist in the mesage, insert
        # the new header in the first position of the Hash.
        @headers = { k => [ value.to_s ] }.merge! @headers
      end
    end

    # Append the given _value_ in the last position of header _name_.
    # _value_ must be a string.
    def append_header name, value
      if hdr = @headers[k=MessageParser.headerize(name)]
        hdr.push value.to_s
      else
        @headers[k] = [ value.to_s ]
      end
    end

    # Replaces the top value of the given header _name_ with the
    # string given as argument _value_.
    def replace_header_top name, value
      if hdr = @headers[k=MessageParser.headerize(name)]
        hdr[0] = value.to_s
      else
        @headers[k] = [ value.to_s ]
      end
    end

    # Close the connection from which the SIP request/response has been
    # received.
    def close_connection
      return false  if @transport == :udp
      @connection.close_connection
      true
    end

  end  # class Message

end
