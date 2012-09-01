module OverSIP

  # This module is intended for 3rd party modules that need custom code to be
  # executed when OverSIP is started, reloaded or terminated.
  #
  module SystemCallbacks

    extend ::OverSIP::Logger

    class << self
      attr_reader :on_started_callbacks
      attr_reader :on_terminated_callbacks
      attr_reader :on_reload_callbacks
    end

    @on_started_callbacks = []
    @on_terminated_callbacks = []
    @on_reload_callbacks = []

    def self.on_started pr=nil, &bl
      block = pr || bl
      raise ::ArgumentError, "no block given"  unless block.is_a? ::Proc

      @on_started_callbacks << block
    end

    def self.on_terminated pr=nil, &bl
      block = pr || bl
      raise ::ArgumentError, "no block given"  unless block.is_a? ::Proc

      @on_terminated_callbacks << block
    end

    def self.on_reload pr=nil, &bl
      block = pr || bl
      raise ::ArgumentError, "no block given"  unless block.is_a? ::Proc

      @on_reload_callbacks << block
    end

  end

end