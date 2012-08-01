# -*- encoding: utf-8 -*-

module OverSIP

  module Version
    MAJOR = 1
    MINOR = 0
    TINY  = 6
    DEVEL = "beta2"  # Set to nil for stable releases.
  end

  PROGRAM_NAME     = "OverSIP"
  PROGRAM_NAME_LOW = PROGRAM_NAME.downcase
  PROGRAM_DESC     = "OverSIP Server"
  VERSION = [Version::MAJOR, Version::MINOR, Version::TINY].join(".")
  VERSION << ".#{Version::DEVEL}"  if Version::DEVEL
  AUTHOR = "Inaki Baz Castillo"
  AUTHOR_EMAIL = "ibc@aliax.net"
  DESCRIPTION = "#{PROGRAM_NAME} #{VERSION}\n2012, #{AUTHOR} <#{AUTHOR_EMAIL}>"

end
