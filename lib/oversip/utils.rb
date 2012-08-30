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
    # NOTE: expression argument must be a Regexp expression (with / symbols at the
    # begining and at the end).
    def self.regexp_compare string, expression
      string = string.to_s
      return false  unless string.valid_encoding?
      string.force_encoding(::Encoding::BINARY) =~ expression
    end

  end

end