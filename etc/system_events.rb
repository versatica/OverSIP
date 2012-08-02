#
# OverSIP - System Events.
#
#
# OverSIP system callbacks. Fill them according to your needs.


module OverSIP::SystemEvents

  extend ::OverSIP::Logger
  @log_id = "SystemEvents"

  # This method is called once the OverSIP reactor has been started.
  def self.on_started
    # Do something.
  end

  # This method is called when a USR1 signal is received by the main
  # process and allows the user to set custom code to be executed
  # or reloaded.
  def self.on_user_reload
    # Do something.
  end

end
