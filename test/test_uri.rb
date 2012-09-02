# coding: utf-8

require "oversip_test_helper"


class TestUri < OverSIPTest

  def test_sip_uri
    full_uri = "sip:i%C3%B1aki@aliax.net:5060;transport=tcp;foo=123;baz?X-Header-1=qwe&X-Header-2=asd"
    aor = "sip:i%C3%B1aki@aliax.net"

    uri = ::OverSIP::SIP::Uri.new
    uri.instance_variable_set :@scheme, :sip
    uri.user = "iñaki"
    uri.host = "aliax.net"
    uri.host_type = :domain
    uri.port = 5060
    uri.transport_param = :tcp
    uri.instance_variable_set :@params, {"transport"=>"tcp", "foo"=>"123", "baz"=>nil}
    uri.headers = "?X-Header-1=qwe&X-Header-2=asd"

    assert_equal "iñaki", uri.user
    assert_equal aor, uri.aor
    assert_equal full_uri, uri.to_s
  end

  def test_tel_uri
    full_uri = "tel:944991212;foo=bar;phone-context=+34"
    aor = "tel:944991212"

    uri = ::OverSIP::SIP::Uri.new
    uri.instance_variable_set :@scheme, :tel
    uri.user = "944991212"
    uri.instance_variable_set :@params, {"foo"=>"bar"}
    uri.phone_context_param = "+34"

    assert_equal aor, uri.aor
    assert_equal full_uri, uri.to_s
  end

  def test_http_uri
    full_uri = "http://oversip.net/authors/"
    aor = nil

    uri = ::OverSIP::SIP::Uri.new
    uri.instance_variable_set :@uri, full_uri

    assert_nil uri.aor
    assert_equal full_uri, uri.to_s
  end
end
