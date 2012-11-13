module Process

  # Ruby 1.9.2 has not defined the constant Process::RLIMIT_MSGQUEUE (Ruby 1.9.3 has it).
  # Gives it value 12 if not defined.
  unless defined? ::Process::RLIMIT_MSGQUEUE
    Process.const_set :RLIMIT_MSGQUEUE, 12
  end

end