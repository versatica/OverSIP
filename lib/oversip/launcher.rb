module OverSIP::Launcher

  extend ::OverSIP::Logger

  READY_PIPE_TIMEOUT = 16

  @log_id = "launcher"


  def self.daemonize! options
    @log_id = "launcher (daemonize)"

    $stdin.reopen("/dev/null")

    # grandparent (launcher)  : Reads pipe, exits when master is ready.
    #  \_ parent              : Exits immediately ASAP.
    #      \_ master          : Writes to pipe when ready.

    rd, wr = IO.pipe
    grandparent = $$
    if fork
      wr.close # Grandparent does not write in the ready_pipe.
    else
      rd.close # Parent (so also future master) does not read from the ready_pipe.
      ::Process.setsid
      exit if fork # Parent dies now.
    end

    # I'm grandparent (launcher) process.
    if grandparent == $$
      # Master process will inmediatelly write in the ready_pipe its PID so we get
      # its PID.
      master_pid = nil
      begin
        ::Timeout.timeout(READY_PIPE_TIMEOUT/2) do
          master_pid = rd.gets("\n").to_i rescue nil
        end
      rescue ::Timeout::Error
        fatal "master process didn't notify its PID within #{READY_PIPE_TIMEOUT/2} seconds"
      end
      unless master_pid
        fatal "master process failed to start"
      end

      # This will block until OverSIP::Launcher.run ends succesfully (so master process
      # writes "ok" in the ready_pipe) or until the pipe is closes without writting into it
      # (so the master process has died).
      # It can also occur that master process blocks forever and never writes into the
      # ready pipe neither closes it. In this case a timeout is raised and master process
      # is killed.
      master_ok = nil
      begin
        ::Timeout::timeout(READY_PIPE_TIMEOUT/2) do
          master_ok = (rd.read(2) rescue nil)
        end
      rescue ::Timeout::Error
        log_system_crit "master process is not ready within #{READY_PIPE_TIMEOUT/2} seconds, killing it..."
        begin
          ::Process.kill(:TERM, master_pid)
          10.times do |i|
            sleep 0.05
            ::Process.wait(master_pid, ::Process::WNOHANG) rescue nil
            ::Process.kill(0, master_pid) rescue break
          end
          ::Process.kill(0, master_pid)
          ::Process.kill(:KILL, master_pid) rescue nil
        rescue ::Errno::ESRCH
        end
        fatal "master process killed"
      end
      unless master_ok == "ok"
        fatal "master process failed to start"
      end

      # Grandparent can die now with honor.
      exit 0

      # I'm master process.
    else
      options[:ready_pipe] = wr
    end
  end


  def self.run options
    @log_id = "launcher (run)"

    configuration = ::OverSIP.configuration

    # Store the master process PID.
    ::OverSIP.master_pid = $$

    begin
      # Inmediatelly write into the ready_pipe so grandparent process reads it
      # and knowns which PID we have.
      ready_pipe = options.delete(:ready_pipe)
      ready_pipe.write($$.to_s + "\n") if ready_pipe

      # I'm master process.
      if (syslogger_pid = fork) != nil
        ::OverSIP.syslogger_pid = syslogger_pid
        ::OverSIP::Logger.load_methods

        # Load all the libraries for the master process.
        require "oversip/master_process.rb"

        ::OverSIP::TLS.module_init
        ::OverSIP::SIP.module_init
        ::OverSIP::SIP::RFC3263.module_init
        ::OverSIP::WebSocket.module_init
        ::OverSIP::WebSocket::WsSipApp.class_init
        ::OverSIP::Security.module_init

      # I'm the syslogger process.
      else
        # Close the pipe in the syslogger process.
        ready_pipe.close rescue nil
        ready_pipe = nil

        require "oversip/syslogger_process.rb"
        ::OverSIP::SysLoggerProcess.run options
        exit
      end

      @log_id = "launcher (master)"

      ::EM.run do

        ::OverSIP.is_ready = false
        ::OverSIP.status = :loading
        ::OverSIP.root_fiber = ::Fiber.current

        log_system_notice "using Ruby #{RUBY_VERSION}p#{RUBY_PATCHLEVEL} (#{RUBY_RELEASE_DATE} revision #{RUBY_REVISION}) [#{RUBY_PLATFORM}]"
        log_system_notice "using EventMachine-LE #{::EM::VERSION}"
        log_system_notice "starting event reactor..."

        # Run SIP and WebSocket servers.
        run_servers options

        # Run DNS resolver.
        ::OverSIP::SIP::RFC3263.run

        # Change process permissions if requested.
        set_user_group(options[:user], options[:group])

        # Create PID file.
        create_pid_file(options[:pid_file])

        trap_signals

        # Ensure the code in the next SystemEvents and SystemCallbacks are run serially.
        ::Fiber.new do

          # Run OverSIP::SystemEvents.on_initialize.
          log_system_notice "calling OverSIP::SystemEvents.on_initialize() method..."
          begin
            ::OverSIP::SystemEvents.on_initialize
          rescue ::Exception => e
            log_system_crit "error calling OverSIP::SystemEvents.on_initialize():"
            fatal e
          end

          # Run all the OverSIP::SystemCallbacks.on_started_callbacks.
          log_system_notice "executing OverSIP::SystemCallbacks.on_started_callbacks..."
          ::OverSIP::SystemCallbacks.on_started_callbacks.each do |cb|
            begin
              cb.call
            rescue ::Exception => e
              log_system_crit "error executing a callback in OverSIP::SystemCallbacks.on_started_callbacks:"
              fatal e
            end
          end

          # Run OverSIP::SystemEvents.on_started within a fiber.
          log_system_notice "calling OverSIP::SystemEvents.on_started() method..."
          begin
            ::OverSIP::SystemEvents.on_started
          rescue ::Exception => e
            log_system_crit "error calling OverSIP::SystemEvents.on_started():"
            fatal e
          end

          log_system_notice "master process (PID #{$$}) ready"
          log_system_notice "#{::OverSIP::PROGRAM_NAME} #{::OverSIP::VERSION} running in background"

          # Write "ok" into the ready_pipe so grandparent process (launcher)
          # exits with status 0.
          if ready_pipe
            ready_pipe.write("ok")
            ready_pipe.close rescue nil
            ready_pipe = nil
          end

          # Stop writting into standard output/error.
          $stdout.reopen("/dev/null")
          $stderr.reopen("/dev/null")
          ::OverSIP.daemonized = true
          # So update the logger to write to syslog.
          ::OverSIP::Logger.load_methods

          # Set the EventMachine error handler.
          ::EM.error_handler do |e|
            log_system_error "error raised during event loop and rescued by EM.error_handler:"
            log_system_error e
          end

          ::OverSIP.is_ready = true
          ::OverSIP.status = :running

        end.resume

      end  # ::EM.run

    rescue => e
      fatal e
    end

  end # def self.run


  def self.fatal msg
    log_system_crit msg
    log_system_crit "exiting with error status"

    terminate error=true, fatal=true
  end


  def self.create_pid_file path
    # Check that the PID file is accesible.
    begin
      assert_file_is_writable_readable_deletable(path)
    rescue ::OverSIP::Error => e
      fatal "cannot create PID file: #{e.message}"
    end
    # If the PID file exists (it shouldn't) check if it's stale.
    if wpid = valid_pid?(path) and wpid != $$
      fatal "already running on PID #{wpid} (or '#{path}' is stale)"
    end
    # Delete the PID file if it exists.
    ::File.unlink(path) rescue nil
    # Create the PID file.
    ::File.open(path, "w", 0644) do |f|
      f.syswrite("#$$\n")
    end
    ::OverSIP.pid_file = path
  end


  def self.assert_file_is_writable_readable_deletable path
    # File already exists.
    if ::File.exist?(path)
      if not ::File.file?(path)
        raise ::OverSIP::Error, "'#{path}' exits and is not a regular file"
      elsif not ::File.readable?(path)
        raise ::OverSIP::Error, "'#{path}' is not readable"
      elsif not ::File.writable?(path)
        raise ::OverSIP::Error, "'#{path}' is not writable"
      end
    end
    # Check if the parent directory is writeable.
    if not ::File.writable? ::File.dirname(path)
      raise ::OverSIP::Error, "directory '#{::File.dirname(path)}' is not writable"
    end
  end


  # Returns a PID if a given path contains a non-stale PID file,
  # false otherwise.
  def self.valid_pid? path
    begin
      wpid = ::File.read(path).to_i
      wpid <= 0 and return false
      # If the process exists return its PID.
      ::Process.kill(0, wpid)
      return wpid
    # If the process exists but we don't have permissions over it, return its PID.
    rescue ::Errno::EPERM
      return wpid
    # If the PID file (path) doesn't exist or the process is not running return false.
    rescue ::Errno::ENOENT, ::Errno::ESRCH
      return false
    end
  end


  def self.run_servers options
    configuration = ::OverSIP.configuration

    if configuration[:sip][:sip_udp]
      # SIP UDP IPv4 server.
      if configuration[:sip][:enable_ipv4]
        ::OverSIP::SIP::Launcher.run true, :ipv4, configuration[:sip][:listen_ipv4],
                                      configuration[:sip][:listen_port], :udp
      end

      # SIP IPv6 UDP server.
      if configuration[:sip][:enable_ipv6]
        ::OverSIP::SIP::Launcher.run true, :ipv6, configuration[:sip][:listen_ipv6],
                                      configuration[:sip][:listen_port], :udp
      end
    end

    if configuration[:sip][:sip_tcp]
      # SIP IPv4 TCP server.
      if configuration[:sip][:enable_ipv4]
        ::OverSIP::SIP::Launcher.run true, :ipv4, configuration[:sip][:listen_ipv4],
                                      configuration[:sip][:listen_port], :tcp
      end

      # SIP IPv6 TCP server.
      if configuration[:sip][:enable_ipv6]
        ::OverSIP::SIP::Launcher.run true, :ipv6, configuration[:sip][:listen_ipv6],
                                      configuration[:sip][:listen_port], :tcp
      end
    end

    if configuration[:sip][:sip_tls]
      unless configuration[:sip][:use_tls_tunnel]
        # SIP IPv4 TLS server (native).
        if configuration[:sip][:enable_ipv4]
          ::OverSIP::SIP::Launcher.run true, :ipv4, configuration[:sip][:listen_ipv4],
                                        configuration[:sip][:listen_port_tls], :tls
        end

        # SIP IPv6 TLS server (native).
        if configuration[:sip][:enable_ipv6]
          ::OverSIP::SIP::Launcher.run true, :ipv6, configuration[:sip][:listen_ipv6],
                                        configuration[:sip][:listen_port_tls], :tls
        end
      else
        # SIP IPv4 TLS server (Stud).
        if configuration[:sip][:enable_ipv4]
          ::OverSIP::SIP::Launcher.run true, :ipv4, "127.0.0.1",
                                        configuration[:sip][:listen_port_tls_tunnel], :tls_tunnel,
                                        configuration[:sip][:listen_ipv4],
                                        configuration[:sip][:listen_port_tls]
          ::OverSIP::SIP::Launcher.run false, :ipv4, configuration[:sip][:listen_ipv4],
                                        configuration[:sip][:listen_port_tls], :tls

          # Spawn a Stud process.
          spawn_stud_process options,
                             configuration[:sip][:listen_ipv4], configuration[:sip][:listen_port_tls],
                             "127.0.0.1", configuration[:sip][:listen_port_tls_tunnel],
                             ssl = false
        end

        # SIP IPv6 TLS server (Stud).
        if configuration[:sip][:enable_ipv6]
          ::OverSIP::SIP::Launcher.run true, :ipv6, "::1",
                                        configuration[:sip][:listen_port_tls_tunnel], :tls_tunnel,
                                        configuration[:sip][:listen_ipv6],
                                        configuration[:sip][:listen_port_tls]
          ::OverSIP::SIP::Launcher.run false, :ipv6, configuration[:sip][:listen_ipv6],
                                        configuration[:sip][:listen_port_tls], :tls

          # Spawn a Stud process.
          spawn_stud_process options,
                             configuration[:sip][:listen_ipv6], configuration[:sip][:listen_port_tls],
                             "::1", configuration[:sip][:listen_port_tls_tunnel],
                             ssl = false
        end
      end
    end

    if configuration[:websocket][:sip_ws]
      # WebSocket IPv4 TCP SIP server.
      if configuration[:websocket][:enable_ipv4]
        ::OverSIP::WebSocket::Launcher.run true, :ipv4, configuration[:websocket][:listen_ipv4],
                                                  configuration[:websocket][:listen_port], :ws
      end

      # WebSocket IPv6 TCP SIP server.
      if configuration[:websocket][:enable_ipv6]
        ::OverSIP::WebSocket::Launcher.run true, :ipv6, configuration[:websocket][:listen_ipv6],
                                                  configuration[:websocket][:listen_port], :ws
      end
    end

    if configuration[:websocket][:sip_wss]
      unless configuration[:websocket][:use_tls_tunnel]
        # WebSocket IPv4 TLS SIP server (native).
        if configuration[:websocket][:enable_ipv4]
          ::OverSIP::WebSocket::Launcher.run true, :ipv4, configuration[:websocket][:listen_ipv4],
                                        configuration[:websocket][:listen_port_tls], :wss
        end

        # WebSocket IPv6 TLS SIP server (native).
        if configuration[:websocket][:enable_ipv6]
          ::OverSIP::WebSocket::Launcher.run true, :ipv6, configuration[:websocket][:listen_ipv6],
                                        configuration[:websocket][:listen_port_tls], :wss
        end
      else
        # WebSocket IPv4 TLS SIP server (Stud).
        if configuration[:websocket][:enable_ipv4]
          ::OverSIP::WebSocket::Launcher.run true, :ipv4, "127.0.0.1",
                                        configuration[:websocket][:listen_port_tls_tunnel], :wss_tunnel,
                                        configuration[:websocket][:listen_ipv4],
                                        configuration[:websocket][:listen_port_tls]
          ::OverSIP::WebSocket::Launcher.run false, :ipv4, configuration[:websocket][:listen_ipv4],
                                        configuration[:websocket][:listen_port_tls], :wss

          # Spawn a Stud process.
          spawn_stud_process options,
                             configuration[:websocket][:listen_ipv4], configuration[:websocket][:listen_port_tls],
                             "127.0.0.1", configuration[:websocket][:listen_port_tls_tunnel],
                             ssl = true
        end

        # WebSocket IPv6 TLS SIP server (Stud).
        if configuration[:sip][:enable_ipv6]
          ::OverSIP::WebSocket::Launcher.run true, :ipv6, "::1",
                                        configuration[:websocket][:listen_port_tls_tunnel], :wss_tunnel,
                                        configuration[:websocket][:listen_ipv6],
                                        configuration[:websocket][:listen_port_tls]
          ::OverSIP::WebSocket::Launcher.run false, :ipv6, configuration[:websocket][:listen_ipv6],
                                        configuration[:websocket][:listen_port_tls], :wss

          # Spawn a Stud process.
          spawn_stud_process options,
                             configuration[:websocket][:listen_ipv6], configuration[:websocket][:listen_port_tls],
                             "::1", configuration[:websocket][:listen_port_tls_tunnel],
                             ssl = true
        end
      end
    end
  end


  def self.trap_signals
    # This should never occur (unless some not trapped signal is received
    # and causes Ruby to exit, or maybe the user called "exit()" within its
    # custom code).
    at_exit do
      if $!.is_a? ::SystemExit
        log_system_notice "exiting due to SystemExit..."
        terminate error=false
      else
        log_system_crit "exiting due to an unknown cause ($! = #{$!.inspect})..."
        terminate error=true
      end
    end

    # Signals that cause OverSIP to terminate.
    exit_signals = [:TERM, :QUIT]
    exit_signals.each do |signal|
      trap signal do
        log_system_notice "#{signal} signal received, exiting..."
        terminate error=false
      end
    end

    # Signals that must be ignored.
    ignore_signals = [:ALRM, :INT, :PIPE, :POLL, :PROF, :USR2, :WINCH]
    ignore_signals.each do |signal|
      begin
        trap signal do
          log_system_notice "#{signal.to_s.upcase} signal received, ignored"
        end
      rescue ::ArgumentError
        log_system_notice "cannot trap signal #{signal.to_s.upcase}, it could not exist in this system, ignoring it"
      end
    end

    # Special treatment for VTALRM signal (TODO: since it occurs too much).
    trap :VTALRM do
    end

    # Signal HUP reloads OverSIP system configuration.
    trap :HUP do
      # Ignore another HUP signal until this code is finished.
      original_trap_proc = trap(:HUP){}

      log_system_notice "HUP signal received, reloading configuration files..."
      ::OverSIP::Config.system_reload

      # Run all the OverSIP::SystemCallbacks.on_reload_callbacks.
      log_system_info "executing OverSIP::SystemCallbacks.on_reload_callbacks..."
      ::Fiber.new do
        ::OverSIP::SystemCallbacks.on_reload_callbacks.each do |cb|
          begin
            cb.call
          rescue ::Exception => e
            log_system_crit "error executing a callback in OverSIP::SystemCallbacks.on_reload_callbacks:"
            log_system_crit e
          end
        end

        # Reset the signal handler.
        trap :HUP, original_trap_proc
      end.resume
    end

    # Signal USR1 reloads custom code provided by the user.
    trap :USR1 do
      # Ignore another HUP signal until this code is finished.
      original_trap_proc = trap(:USR1){}

      log_system_notice "USR1 signal received, calling OverSIP::SystemEvents.on_user_reload() method..."
      # Run OverSIP::SystemEvents.on_user_reload.
      ::Fiber.new do
        begin
          ::OverSIP::SystemEvents.on_user_reload
        rescue ::Exception => e
          log_system_crit "error calling OverSIP::SystemEvents.on_user_reload():"
          log_system_crit e
        end

        # Reset the signal handler.
        trap :USR1, original_trap_proc
      end.resume
    end

  end


  def self.terminate error=false, fatal=false
    ::OverSIP.is_ready = false
    ::OverSIP.status = :terminating

    # Trap TERM/QUIT signals (we are already exiting).
    trap(:TERM) {}
    trap(:QUIT) {}

    ::Fiber.new do

      unless fatal
        # Run OverSIP::SystemEvents.on_terminated.
        log_system_info "calling OverSIP::SystemEvents.on_terminated() method..."
        begin
          ::OverSIP::SystemEvents.on_terminated error
        rescue ::Exception => e
          log_system_crit "error calling OverSIP::SystemEvents.on_terminated():"
          log_system_crit e
        end

        # Run all the SystemCallbacks.on_terminated_callbacks in reverse order.
        log_system_info "executing OverSIP::SystemCallbacks.on_terminated_callbacks..."
        ::OverSIP::SystemCallbacks.on_terminated_callbacks.reverse.each do |cb|
          begin
            cb.call error
          rescue ::Exception => e
            log_system_crit "error executing a callback in OverSIP::SystemCallbacks.on_terminated_callbacks:"
            log_system_crit e
          end
        end
      end

      unless error
        log_system_info "exiting, thank you for tasting #{::OverSIP::PROGRAM_NAME}"
      end

      # Kill Stud processes and delete its temporal file with the full certificate.
      kill_stud_processes
      ::File.delete ::OverSIP.configuration[:tls][:full_cert]  rescue nil

      # Wait a bit so pending log messages in the Posix MQ can be queued.
      sleep 0.1
      ::OverSIP::Logger.close

      kill_syslogger_process

      delete_pid_file

      # Exit by preventing any exception.
      exit!( error ? false : true )

    end.resume
  end


  def self.delete_pid_file
    return false  unless ::OverSIP.master_pid

    ::File.delete(::OverSIP.pid_file) rescue nil
  end


  def self.kill_syslogger_process
    return false  unless ::OverSIP.master_pid

    begin
      ::Process.kill(:TERM, ::OverSIP.syslogger_pid)
      10.times do |i|
        sleep 0.05
        ::Process.wait(::OverSIP.syslogger_pid, ::Process::WNOHANG) rescue nil
        ::Process.kill(0, ::OverSIP.syslogger_pid) rescue break
      end
      ::Process.kill(0, ::OverSIP.syslogger_pid)
      ::Process.kill(:KILL, ::OverSIP.syslogger_pid) rescue nil
    rescue ::Errno::ESRCH
    end
  end


  def self.set_user_group user, group
    uid = ::Etc.getpwnam(user).uid  if user
    gid = ::Etc.getgrnam(group).gid  if group
    if uid or gid
      if gid and ::Process.egid != gid
        ::Process.initgroups(user, gid)  if user
        ::Process::GID.change_privilege(gid)
      end
      if uid
        ::Process.euid != uid and ::Process::UID.change_privilege(uid)
      end
    end
  end


  def self.spawn_stud_process options, listen_ip, listen_port, bg_ip, bg_port, ssl=false
    stud_user_group = ""
    stud_user_group << "-u #{options[:user]}" if options[:user]
    stud_user_group << " -g #{options[:group]}" if options[:group]
    ssl_option = ( ssl ? "--ssl" : "" )

    bin_dir = ::File.join(::File.absolute_path(::File.dirname(__FILE__)), "../../bin/")
    stdout_file = "/tmp/stud.#{listen_ip}:#{listen_port}.out"
    stderr_file = "/tmp/stud.#{listen_ip}:#{listen_port}.err"

    ::Dir.chdir(bin_dir) do
      pid = ::POSIX::Spawn.spawn "./oversip_stud #{stud_user_group} #{ssl_option} -f '#{listen_ip},#{listen_port}' -b '#{bg_ip},#{bg_port}' -n 2 -s --daemon --write-proxy #{::OverSIP.configuration[:tls][:full_cert]}", :out => stdout_file, :err => stderr_file
      ::Process.waitpid(pid)
    end

    # Get the PID of the daemonized stud process.
    stdout = ::File.read stdout_file
    pid = nil
    stdout.each_line do |line|
      pid = line.split(" ")[4]
      if pid
        pid = pid.gsub(/\./,"").to_i
        break  if pid > 0
      end
    end
    ::File.delete stdout_file  rescue nil

    unless pid
      stderr = ::File.read stderr_file
      ::File.delete stderr_file  rescue nil
      log_system_crit "error spawning stud server for listening on #{listen_ip} : #{listen_port}:"
      fatal stderr
    end
    ::File.delete stderr_file  rescue nil

    ::OverSIP.stud_pids ||= []
    ::OverSIP.stud_pids << pid

    log_system_info "spawned stud server (PID #{pid}) listening on #{listen_ip} : #{listen_port}"
  end


  def self.kill_stud_processes
    return false  unless ::OverSIP.master_pid
    return false  unless ::OverSIP.stud_pids

    ::OverSIP.stud_pids.each do |pid|
      begin
        log_system_info "killing stud server with PID #{pid}..."
        ::Process.kill(:TERM, pid)
        10.times do |i|
          sleep 0.05
          ::Process.wait(pid, ::Process::WNOHANG) rescue nil
          ::Process.kill(0, pid) rescue break
        end
        ::Process.kill(0, pid)
        ::Process.kill(:KILL, pid) rescue nil
      rescue ::Errno::ESRCH
      end
    end
  end

end
