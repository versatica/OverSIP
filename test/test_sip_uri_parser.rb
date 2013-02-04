# coding: utf-8

require "oversip_test_helper"


class TestSipUriParser < OverSIPTest

  def test_parse_sip_uri
    uri_str = "sips:i%C3%B1aki@aliax.net:5060;transport=tcp;foo=123;baz?X-Header-1=qwe&X-Header-2=asd"
    aor = "sip:i%C3%B1aki@aliax.net"

    uri = ::OverSIP::SIP::Uri.parse uri_str

    assert_equal ::OverSIP::SIP::Uri, uri.class
    assert_true uri.sip?
    assert_false uri.unknown_scheme?
    assert_equal "iñaki", uri.user
    assert_true uri.has_param? "FOO"
    assert_false uri.has_param? "LALALA"
    assert_equal "123", uri.get_param("Foo")
    assert_equal aor, uri.aor
    assert_equal uri_str, uri.to_s
  end

  def test_parse_tel_uri
    uri_str = "tel:944991212;foo=bar;phone-context=+34"
    aor = "tel:944991212"

    uri = ::OverSIP::SIP::Uri.parse uri_str

    assert_equal ::OverSIP::SIP::Uri, uri.class
    assert_true uri.tel?
    assert_false uri.unknown_scheme?
    assert_equal "944991212", uri.number
    assert_true uri.has_param? "FOO"
    assert_false uri.has_param? "LALALA"
    assert_equal "bar", uri.get_param("Foo")
    assert_equal aor, uri.aor
    assert_equal uri_str, uri.to_s
  end

  def test_parse_http_uri
    uri_str = "http://oversip.net/authors/"
    aor = nil

    uri = ::OverSIP::SIP::Uri.parse uri_str

    assert_equal ::OverSIP::SIP::Uri, uri.class
    assert_false uri.sip?
    assert_false uri.tel?
    assert_true uri.unknown_scheme?
    assert_nil uri.has_param? "FOO"
    assert_nil uri.aor
    assert_equal uri_str, uri.to_s
  end
end
