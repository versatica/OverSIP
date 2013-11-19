require "rake/testtask"
require "rake/clean"


OVERSIP_EXTENSIONS = [
  { :dir => "ext/sip_parser", :lib => "sip_parser.#{RbConfig::CONFIG["DLEXT"]}", :dest => "lib/oversip/sip" },
  { :dir => "ext/stun", :lib => "stun.#{RbConfig::CONFIG["DLEXT"]}", :dest => "lib/oversip" },
  { :dir => "ext/utils", :lib => "utils.#{RbConfig::CONFIG["DLEXT"]}", :dest => "lib/oversip" },
  { :dir => "ext/websocket_framing_utils", :lib => "ws_framing_utils.#{RbConfig::CONFIG["DLEXT"]}", :dest => "lib/oversip/websocket" },
  { :dir => "ext/websocket_http_parser", :lib => "ws_http_parser.#{RbConfig::CONFIG["DLEXT"]}", :dest => "lib/oversip/websocket" },
]

OVERSIP_EXTENSIONS.each do |ext|
  file ext[:lib] => Dir.glob(["#{ext[:dir]}/*{.c,.h}"]) do
    Dir.chdir(ext[:dir]) do
      ruby "extconf.rb"
      sh "make"
    end
    cp "#{ext[:dir]}/#{ext[:lib]}", "#{ext[:dest]}/"
  end

  CLEAN.include("#{ext[:dir]}/*{.o,.log,.so,.a,.bundle}")
  CLEAN.include("#{ext[:dir]}/Makefile")
  CLEAN.include("#{ext[:dest]}/#{ext[:lib]}")
end

# Stud stuff.
directory "tmp"
file "bin/oversip_stud" => "tmp" do
  Dir.chdir("ext/stud") do
    ruby "extconf.rb"
  end
  FileUtils.remove_dir "tmp"
end
CLEAN.include("ext/stud/Makefile")
CLEAN.include("thirdparty/stud/mkmf.log")
CLEAN.include("bin/oversip_stud")


OVERSIP_COMPILE_ITEMS = OVERSIP_EXTENSIONS.map {|e| e[:lib]} << "bin/oversip_stud"

task :default => :compile

desc "Compile"
task :compile => OVERSIP_COMPILE_ITEMS

Rake::TestTask.new do |t|
  t.libs << "test"
end

# Make the :test task depend on the shared object, so it will be built automatically
# before running the tests.
desc "Run tests"
task :test => OVERSIP_COMPILE_ITEMS
