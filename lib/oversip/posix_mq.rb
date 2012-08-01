module OverSIP

  class PosixMQ

    extend ::OverSIP::Logger

    def self.create_queue options={}
      @log_id = "PosixMQ #{options[:name]}"

      # Queue attributes.
      mq_name = options[:name]
      mq_mode = case options[:mode]
        when :read       then ::IO::RDONLY
        when :write      then ::IO::WRONLY
        when :read_write then ::IO::RDWR
        end
      mq_group = options[:group]
      mq_attr = ::POSIX_MQ::Attr.new
      # NOTE: maximun value for maxmsg is 65536.
      mq_attr.maxmsg  = options[:maxmsg]
      mq_attr.msgsize = options[:msgsize]
      mq_attr.flags   = 0
      mq_attr.curmsgs = 0

      # Delete the queue if it exists.
      begin
        ::POSIX_MQ.unlink mq_name
      rescue ::Errno::ENOENT
      rescue ::Errno::EACCES => e
        fatal "queue already exists and cannot remove it due file permissions"
      # Kernel has no support for posix message queues.
      rescue ::Errno::ENOSYS => e
        fatal "the kernel has no support for posix messages queues, enable it (#{e.class}: #{e.message})"
      end

      # Set the UMASK in a way that the group has permission to delete the queue.
      orig_umask = ::File.umask(0007)

      # Change the effective group for the Posix queue. Keep the original
      # group.
      orig_gid = ::Process::GID.eid
      if mq_group
        gid = ::Etc.getgrnam(mq_group).gid
        ::Process::GID.change_privilege(gid)
      end

      # System limits required size (ulimit -q).
      mq_size = case 1.size
        # 32 bits OS.
        when 4 then mq_attr.maxmsg * 4 + mq_attr.maxmsg * mq_attr.msgsize
        # 64 bits OS.
        when 8 then mq_attr.maxmsg * 8 + mq_attr.maxmsg * mq_attr.msgsize
        end

      log_system_info "queue requires #{mq_size} bytes"

      # Set RLIMIT_MSGQUEUE (ulimit) in order to create the queue with required
      # ammount of memory.
      if ( current_rlimit = ::Process.getrlimit(12)[1] ) < mq_size
        log_system_info "incrementing rlimits for Posix Message Queues (currently #{current_rlimit} bytes) to #{mq_size} bytes (ulimit -q)"
        begin
          ::Process.setrlimit(12, mq_size)
        rescue ::Errno::EPERM
          fatal "current user has no permissions to increase rlimits to #{mq_size} bytes (ulimit -q)"
        end
      else
        log_system_info "rlimits for Posix Message Queues is #{current_rlimit} bytes (>= #{mq_size}), no need to increase it"
      end

      # Create the Posix message queue to write into it.
      # - IO::WRONLY   =>  Just write.
      # - IO::CREAT    =>  Create if it doesn't exist.
      # - IO::EXCL     =>  Raise if the queue already exists.
      # - IO::NONBLOCK =>  Don't block when sending (instead raise Errno::EAGAIN).
      # - mode: 00660  =>  User and group can write and read.
      # - mq_attr      =>  Set maxmsg and msgsize.
      begin
        mq = ::POSIX_MQ.new mq_name, mq_mode | ::IO::CREAT | ::IO::EXCL | ::IO::NONBLOCK, 00660, mq_attr

      # Kernel has no support for posix message queues.
      rescue ::Errno::ENOSYS => e
        fatal "the kernel has no support for posix messages queues, enable it (#{e.class}: #{e.message})"

      # http://linux.die.net/man/3/mq_open
      #
      # IO_CREAT was specified in oflag, and attr was not NULL, but attr->mq_maxmsg or attr->mq_msqsize was
      # invalid. Both of these fields must be greater than zero. In a process that is unprivileged (does not
      # have the CAP_SYS_RESOURCE capability), attr->mq_maxmsg must be less than or equal to the msg_max
      # limit, and attr->mq_msgsize must be less than or equal to the msgsize_max limit. In addition, even
      # in a privileged process, attr->mq_maxmsg cannot exceed the HARD_MAX limit. (See mq_overview(7) for
      # details of these limits.)
      rescue ::Errno::EINVAL
        log_system_warn "cannot set queue attributes due to user permissions, using system default values"
        mq = ::POSIX_MQ.new mq_name, mq_mode | ::IO::CREAT | ::IO::NONBLOCK, 00660
      rescue ::Errno::ENOMEM => e
        fatal "insufficient memory (#{e.class}: #{e.message})"
      rescue ::Errno::EMFILE => e
        fatal "the process already has the maximum number of files and message queues open (#{e.class}: #{e.message})"
      rescue Errno::ENFILE => e
        fatal "the system limit on the total number of open files and message queues has been reached (#{e.class}: #{e.message})"
      rescue ::Errno::ENOSPC => e
        fatal "insufficient space for the creation of a new message queue, probably occurred because the queues_max limit was encountered (#{e.class}: #{e.message})"

      end

      # Recover the original Umask settings.
      ::File.umask(orig_umask)

      # Recover the original effective group.
      ::Process::GID.change_privilege(orig_gid)  if mq_group

      if mq.attr.maxmsg == mq_attr.maxmsg and mq.attr.msgsize == mq_attr.msgsize
        log_system_debug "maxmsg=#{mq.attr.maxmsg}, msgsize=#{mq.attr.msgsize}"  if $oversip_debug
      else
        log_system_warn "maxmsg=#{mq.attr.maxmsg}, msgsize=#{mq.attr.msgsize}, " \
                    "but recommended values are maxmsg=#{mq_attr.maxmsg}, msgsize=#{mq_attr.msgsize}"
      end

      mq
    end  # self.create_queue

  end  # class PosixMQ

end
