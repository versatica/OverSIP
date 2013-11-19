require "test/unit"
require "oversip"


class OverSIPTest < Test::Unit::TestCase

  def assert_true(object, message="")
    assert_equal(true, object, message)
  end

  def assert_false(object, message="")
    assert_equal(false, object, message)
  end

  def assert_equal_options(options, element)
    assert options.include?(element)
  end

end
