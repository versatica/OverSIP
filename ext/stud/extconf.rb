require "mkmf"
require "fileutils"
require "rbconfig"


def log(message)
  puts "[ext/stud/extconf.rb] #{message}"
end


def sys(cmd)
  log "executing system command: #{cmd}"
  unless ret = xsystem(cmd)
    raise "[ext/stud/extconf.rb] system command `#{cmd}' failed"
  end
  ret
end


here = File.expand_path(File.dirname(__FILE__))
stud_dir = "#{here}/../../thirdparty/stud/"
stud_tarball = "stud.tar.gz"

Dir.chdir(stud_dir) do
  sys("tar -zxf #{stud_tarball}")

  Dir.chdir("stud") do
    host_os = RbConfig::CONFIG["host_os"]
    log "RbConfig::CONFIG['host_os'] returns #{host_os.inspect}"
    case host_os
    when /bsd/i
      log "BSD detected, using `gmake' instead of `make'"
      sys("gmake")
    else
      sys("make")
    end
    FileUtils.mv "stud", "../../../bin/oversip_stud"
  end

  FileUtils.remove_dir("stud", force = true)
end

create_makefile("stud")
