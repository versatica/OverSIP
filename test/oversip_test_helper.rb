require "test/unit"
require "oversip"
require "oversip/master_process"


class OverSIPTest < Test::Unit::TestCase

  def assert_true(object, message="")
    assert_equal(object, true, message)
  end

  def assert_false(object, message="")
    assert_equal(object, false, message)
  end

  def assert_equal_options(options, element)
    assert options.include?(element)
  end

end
