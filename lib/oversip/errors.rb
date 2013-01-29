module OverSIP

  class Error < ::StandardError ; end

  class ConfigurationError < Error ; end
  class RuntimeError < Error ; end

  class ParsingError < RuntimeError ; end

end