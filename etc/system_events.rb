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

end
