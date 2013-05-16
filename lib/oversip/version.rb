# -*- encoding: utf-8 -*-

module OverSIP

  module Version
    MAJOR = 1
    MINOR = 3
    TINY  = 8
    DEVEL = nil  # Set to nil for stable releases.
  end

  PROGRAM_NAME     = "OverSIP"
  VERSION = [Version::MAJOR, Version::MINOR, Version::TINY].join(".")
  VERSION << ".#{Version::DEVEL}"  if Version::DEVEL
  AUTHOR = "Inaki Baz Castillo"
  AUTHOR_EMAIL = "ibc@aliax.net"
  HOMEPAGE = "http://www.oversip.net"
  year = "2012-2013"
  DESCRIPTION = "#{PROGRAM_NAME} #{VERSION}\n#{HOMEPAGE}\n#{year}, #{AUTHOR} <#{AUTHOR_EMAIL}>"

end
