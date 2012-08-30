module OverSIP

  module Utils

    # It ensures that two identical byte secuences are matched regardless
    # they have different encoding.
    # For example in Ruby the following returns false:
    #   "iñaki".force_encoding(::Encoding::BINARY) == "iñaki"
    def self.string_compare string1, string2
      string1.to_s.force_encoding(::Encoding::BINARY) == string2.to_s.force_encoding(::Encoding::BINARY)
    end

    # This avoid "invalid byte sequence in UTF-8" when the directly doing:
    #   string =~ /EXPRESSION/
    # and string has invalid UTF-8 bytes secuence.
    # Also avoids "incompatible encoding regexp match (UTF-8 regexp with ASCII-8BIT string)"
    # NOTE: expression argument must be a String or a Regexp.
    def self.regexp_compare string, expression
      string = string.to_s.force_encoding(::Encoding::BINARY)
      if expression.is_a? ::Regexp
        expression = /#{expression.source.force_encoding(::Encoding::BINARY)}/
      else
        expression = /#{expression.to_s.force_encoding(::Encoding::BINARY)}/
      end
      string =~ expression
    end

  end

end