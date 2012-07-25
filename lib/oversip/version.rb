# -*- encoding: utf-8 -*-

module OverSIP

  module Version
    MAJOR = 1
    MINOR = 0
    TINY  = 3
  end

  PROGRAM_NAME     = "OverSIP"
  PROGRAM_NAME_LOW = PROGRAM_NAME.downcase
  PROGRAM_DESC     = "OverSIP Server"
  VERSION = [Version::MAJOR, Version::MINOR, Version::TINY].join('.')
  AUTHOR = "Iñaki Baz Castillo"
  AUTHOR_EMAIL = "ibc@aliax.net"
  DESCRIPTION = "#{PROGRAM_NAME} #{VERSION}\n2012, #{AUTHOR} <#{AUTHOR_EMAIL}>"

  module GemVersion
    VERSION = ::OverSIP::VERSION
  end

end
