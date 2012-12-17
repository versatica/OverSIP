# coding: utf-8

require "oversip_test_helper"


class TestNameAddr < OverSIPTest

  def test_name_addr
    full_name_addr = '"Iñaki Baz Castillo" <sips:i%C3%B1aki@aliax.net:5060;transport=tcp;foo=123;baz?X-Header-1=qwe&X-Header-2=asd>'
    aor = "sip:i%C3%B1aki@aliax.net"

    name_addr = ::OverSIP::SIP::NameAddr.new "Iñaki Baz Castillo", :sips, "iñaki", "aliax.net", 5060
    name_addr.transport_param = :tcp
    name_addr.set_param "FOO", "123"
    name_addr.set_param "baz", nil
    name_addr.headers = "?X-Header-1=qwe&X-Header-2=asd"

    assert_true name_addr.sip?
    assert_false name_addr.tel?
    assert_false name_addr.unknown_scheme?
    assert_equal "iñaki", name_addr.user
    assert_equal "123", name_addr.get_param("Foo")
    assert_equal aor, name_addr.aor
    assert_equal full_name_addr, name_addr.to_s
  end

end
