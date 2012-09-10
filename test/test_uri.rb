# coding: utf-8

require "oversip_test_helper"


class TestUri < OverSIPTest

  def test_sip_uri
    full_uri = "sips:i%C3%B1aki@aliax.net:5060;transport=tcp;foo=123;baz?X-Header-1=qwe&X-Header-2=asd"
    aor = "sip:i%C3%B1aki@aliax.net"

    uri = ::OverSIP::SIP::Uri.new :sips, "iñaki", "aliax.net", 5060
    uri.transport_param = :tcp
    uri.set_param "FOO", "123"
    uri.set_param "baz", nil
    uri.headers = "?X-Header-1=qwe&X-Header-2=asd"

    assert_equal "iñaki", uri.user
    assert_equal "123", uri.get_param("Foo")
    assert_equal aor, uri.aor
    assert_equal full_uri, uri.to_s
  end

  def test_tel_uri
    full_uri = "tel:944991212;foo=bar;phone-context=+34"
    aor = "tel:944991212"

    uri = ::OverSIP::SIP::Uri.new :tel, "944991212"
    uri.set_param "FOO", "bar"
    uri.phone_context_param = "+34"

    assert_equal "944991212", uri.number
    assert_equal "bar", uri.get_param("Foo")
    assert_equal aor, uri.aor
    assert_equal full_uri, uri.to_s
  end

  def test_http_uri
    full_uri = "http://oversip.net/authors/"
    aor = nil

    uri = ::OverSIP::SIP::Uri.allocate
    uri.instance_variable_set :@uri, full_uri

    assert_nil uri.aor
    assert_equal full_uri, uri.to_s
  end
end
