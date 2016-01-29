# -*- encoding: utf-8 -*-

module OverSIP

  module Version
    MAJOR = 2
    MINOR = 0
    TINY  = 3
    DEVEL = nil  # Set to nil for stable releases.
  end

  PROGRAM_NAME     = "OverSIP"
  VERSION = [Version::MAJOR, Version::MINOR, Version::TINY].join(".")
  VERSION << ".#{Version::DEVEL}"  if Version::DEVEL
  AUTHOR = "Inaki Baz Castillo"
  AUTHOR_EMAIL = "ibc@aliax.net"
  HOMEPAGE = "http://oversip.net"
  year = "2012-2014"
  DESCRIPTION = "#{PROGRAM_NAME} #{VERSION}\n#{HOMEPAGE}\n#{year}, #{AUTHOR} <#{AUTHOR_EMAIL}>"

end
