module OverSIP::SIP

  module Tags

    PREFIX_FOR_TOTAG_SL_REPLIED = ::SecureRandom.hex(4) + "."
    REGEX_PREFIX_FOR_TOTAG_SL_REPLIED = /^#{PREFIX_FOR_TOTAG_SL_REPLIED}/

    ROUTE_OVID_VALUE = ::SecureRandom.hex(4)
    ROUTE_OVID_VALUE_HASH = ROUTE_OVID_VALUE.hash

    ANTILOOP_CONST = ::SecureRandom.hex(1)


    def self.totag_for_sl_reply
      PREFIX_FOR_TOTAG_SL_REPLIED + ::SecureRandom.hex(4)
    end

    def self.check_totag_for_sl_reply totag
      return nil unless totag
      totag =~ REGEX_PREFIX_FOR_TOTAG_SL_REPLIED
    end

    def self.value_for_route_ovid
      ROUTE_OVID_VALUE
    end

    def self.check_value_for_route_ovid value
      return nil unless value
      value.hash == ROUTE_OVID_VALUE_HASH
    end

    def self.create_antiloop_id request
      # It produces a 32 chars string.
      ::Digest::MD5.hexdigest "#{ANTILOOP_CONST}#{request.ruri.to_s}#{request.call_id}#{request.routes[0].uri if request.routes}"
    end

  end

end
