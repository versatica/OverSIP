# coding: utf-8

require "oversip_test_helper"


class TestNameAddrParser < OverSIPTest

  def test_parse_name_addr
    name_addr_str = '"Iñaki" <sips:i%C3%B1aki@aliax.net:5060;transport=tcp;foo=123;baz?X-Header-1=qwe&X-Header-2=asd>'
    aor = "sip:i%C3%B1aki@aliax.net"

    name_addr = ::OverSIP::SIP::NameAddr.parse name_addr_str

    assert_equal ::OverSIP::SIP::NameAddr, name_addr.class
    assert_equal "Iñaki", name_addr.display_name
    assert_true name_addr.sip?
    assert_false name_addr.unknown_scheme?
    assert_equal "iñaki", name_addr.user
    assert_equal "123", name_addr.get_param("Foo")
    assert_equal aor, name_addr.aor
    assert_equal name_addr_str, name_addr.to_s
  end

end
