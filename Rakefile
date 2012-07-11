require "rake/testtask"
require "rake/clean"


OVERSIP_EXTENSIONS = [
  { :dir => "ext/sip_parser", :so => "sip_parser.so", :dest => "lib/oversip/sip" },
  { :dir => "ext/stun", :so => "stun.so", :dest => "lib/oversip" },
  { :dir => "ext/utils", :so => "utils.so", :dest => "lib/oversip" },
  { :dir => "ext/websocket_framing_utils", :so => "ws_framing_utils.so", :dest => "lib/oversip/websocket" },
  { :dir => "ext/websocket_http_parser", :so => "ws_http_parser.so", :dest => "lib/oversip/websocket" },
]

OVERSIP_EXTENSIONS.each do |ext|
  file ext[:so] => Dir.glob(["#{ext[:dir]}/*{.c,.h}"]) do
    Dir.chdir(ext[:dir]) do
      ruby "extconf.rb"
      sh "make"
    end
    cp "#{ext[:dir]}/#{ext[:so]}", "#{ext[:dest]}/"
  end

  CLEAN.include("#{ext[:dir]}/*{.o,.log,.so,.a}")
  CLEAN.include("#{ext[:dir]}/Makefile")
  CLEAN.include("#{ext[:dest]}/#{ext[:so]}")
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


OVERSIP_COMPILE_ITEMS = OVERSIP_EXTENSIONS.map {|e| e[:so]} << "bin/oversip_stud"


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
