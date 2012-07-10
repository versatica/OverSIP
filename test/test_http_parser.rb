# coding: utf-8

require "oversip_test_helper"


class TestHttpParser < OverSIPTest

  def parse data
    parser = OverSIP::WebSocket::HttpRequestParser.new
    buffer = IO::Buffer.new
    request = OverSIP::WebSocket::HttpRequest.new

    buffer << data

    unless bytes_parsed = parser.execute(request, buffer.to_str, 0)
      raise "ERROR: parsing error: \"#{parser.error}\""
    end

    if parser.finished?
      buffer.read bytes_parsed
      if request.content_length and ! request.content_length.zero?
        request.body = buffer.read request.content_length
      end
      if buffer.size != 0
        raise "ERROR: buffer is not empty after parsing"
      end
    else
      raise "ERROR: parsed NOT finished!"
    end

    [parser, request]
  end
  private :parse

  def test_parse_http_get
    parser, request = parse <<-END
GET http://server.example.coM./chat?qwe=QWE&asd=#fragment HTTP/1.1\r
Host: server.example.Com.\r
Upgrade: WebSocket\r
Connection: keep-Alive ,  Upgrade\r
Sec-WebSocket-Key: dGhlIHNhbXBsZSBub25jZQ==\r
Sec-WebSocket-protocol: foo , chat.lalala.com\r
Sec-WebSocket-protocol:  xmpp.nonaino.org\r
Origin: http://example.Com\r
Sec-WebSocket-Version: 8\r
noNaino-lALA  :  qwe\r
NOnaino-lala: asd\r
\r
END

    assert_equal request.http_method, :GET
    assert_equal request.http_version, "HTTP/1.1"

    assert_equal "/chat?qwe=QWE&asd=", request.uri
    assert_equal "/chat", request.uri_path
    assert_equal "qwe=QWE&asd=", request.uri_query
    assert_equal "fragment", request.uri_fragment
    assert_equal request.uri_scheme, :http
    assert_equal "server.example.com", request.host
    assert_nil request.port

    assert_nil request.content_length
    assert request.hdr_connection.include?("upgrade")
    assert_equal "websocket", request.hdr_upgrade
    assert_equal 8, request.hdr_sec_websocket_version
    assert_equal "dGhlIHNhbXBsZSBub25jZQ==", request.hdr_sec_websocket_key
    assert_equal "http://example.com", request.hdr_origin
    assert_equal ["foo", "chat.lalala.com", "xmpp.nonaino.org"], request.hdr_sec_websocket_protocol

    assert_equal ["qwe", "asd"], request["Nonaino-Lala"]
  end

end
