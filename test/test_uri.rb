# coding: utf-8

require "oversip_test_helper"


class TestUri < OverSIPTest

  def test_sip_uri
    full_uri = "sip:alice@atlanta.com:5060;transport=tcp;foo=123;baz?X-Header-1=qwe&X-Header-2=asd"

    uri = ::OverSIP::SIP::Uri.new
    uri.instance_variable_set :@scheme, :sip
    uri.user = "alice"
    uri.host = "atlanta.com"
    uri.host_type = :domain
    uri.port = 5060
    uri.transport_param = :tcp
    uri.instance_variable_set :@params, {"transport"=>"tcp", "foo"=>"123", "baz"=>nil}
    uri.headers = "?X-Header-1=qwe&X-Header-2=asd"

    assert_equal full_uri, uri.to_s
  end

  def test_tel_uri
    full_uri = "tel:944991212;foo=bar;phone-context=+34"

    uri = ::OverSIP::SIP::Uri.new
    uri.instance_variable_set :@scheme, :tel
    uri.user = "944991212"
    uri.instance_variable_set :@params, {"foo"=>"bar"}
    uri.phone_context_param = "+34"

    assert_equal full_uri, uri.to_s
  end

  def test_http_uri
    full_uri = "http://oversip.net/authors/"

    uri = ::OverSIP::SIP::Uri.new
    uri.instance_variable_set :@uri, full_uri

    assert_equal full_uri, uri.to_s
  end
end
