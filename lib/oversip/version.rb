# -*- encoding: utf-8 -*-

module OverSIP

  module Version
    MAJOR = 1
    MINOR = 1
    TINY  = 0
    DEVEL = "beta4"  # Set to nil for stable releases.
  end

  PROGRAM_NAME     = "OverSIP"
  PROGRAM_NAME_LOW = PROGRAM_NAME.downcase
  PROGRAM_DESC     = "OverSIP Server"
  VERSION = [Version::MAJOR, Version::MINOR, Version::TINY].join(".")
  VERSION << ".#{Version::DEVEL}"  if Version::DEVEL
  AUTHOR = "Inaki Baz Castillo"
  AUTHOR_EMAIL = "ibc@aliax.net"
  WEB = "http://www.oversip.net"
  DESCRIPTION = "#{PROGRAM_NAME} #{VERSION}\n#{WEB}\n#{Time.now.year}, #{AUTHOR} <#{AUTHOR_EMAIL}>"

end
