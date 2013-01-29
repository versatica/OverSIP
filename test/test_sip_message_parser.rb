# coding: utf-8

require "oversip_test_helper"


class TestSipMessageParser < OverSIPTest

  def parse data
    parser = OverSIP::SIP::MessageParser.new
    buffer = IO::Buffer.new

    buffer << data

    unless bytes_parsed = parser.execute(buffer.to_str, 0)
      raise "ERROR: parsing error for class #{parser.parsed.class}: \"#{parser.error}\""
    end

    msg = parser.parsed

    if parser.finished?
      buffer.read bytes_parsed
      if msg.content_length and ! msg.content_length.zero?
        msg.body = buffer.read msg.content_length
      end
      if buffer.size != 0
        raise "ERROR: buffer is not empty after parsing"
      end
    else
      raise "ERROR: parsed NOT finished! (msg.class = #{msg.class})"
    end

    parser.post_parsing

    [parser, msg]
  end
  private :parse

  def test_parse_sip_invite
    parser, msg = parse <<-END
INVITE sip:sips%3Auser%40example.com@example.NET.;transport=tcp;FOO=baz?Subject=lalala SIP/2.0\r
via: SIP/2.0/UDP host5.example.net;branch=z9hG4bKkdjuw ; Rport\r
v: SIP/2.0/TCP 1.2.3.4;branch=z9hG4bKkdjuw\r
To: <tel:+(34)-94-499-44-22;lalala=lololo>\r
from: <sips:I%20have%20spaces@[2001:123:Ab:0:0::123]:9999> ;\r
  tag=938\r
Route: <sip:qweqwe/.+asdasd@1.2.3.4:7777;LR;ob>,\r
  "Server Ñ€áéíóú" <SIP:[01::000:A0f]:6666;lr>\r
Max-Forwards: 87\r
_i: esc01.239409asdfakjkn23onasd0-3234\r
CSeq: 234234 INVITE\r
C: application/sdp\r
Require: AAA, Bbb\r
Require: ccc\r
Proxy-Require: AAA, Bbb\r
Proxy-Require: ccc\r
Supported: AAA, Bbb\r
k: ccc\r
Contact:\r
 <sip:cal%6Cer@host5.example.net;%6C%72;n%61me=v%61lue%25%34%31;ob>;p1=foo;P2=BAR;+sip-instance=qweqwe;reg-id=1\r
Content-Length: 150\r
\r
v=0\r
o=mhandley 29739 7272939 IN IP4 192.0.2.1\r
s=-\r
c=IN IP4 192.0.2.1\r
t=0 0\r
m=audio 49217 RTP/AVP 0 12\r
m=video 3227 RTP/AVP 31\r
a=rtpmap:31 LPC\r
END

    assert_equal msg.class, OverSIP::SIP::Request
    assert_equal msg.sip_method, :INVITE
    assert_equal msg.sip_version, "SIP/2.0"
    assert_true msg.initial?

    assert_false parser.duplicated_core_header?
    assert_equal parser.missing_core_header?, "Call-ID"

    assert_equal msg.num_vias, 2
    assert_equal msg.via_sent_by_host, "host5.example.net"
    assert_nil msg.via_sent_by_port
    assert_nil msg.via_received
    assert_true msg.via_rport?
    assert_equal msg.via_core_value, "SIP/2.0/UDP host5.example.net"
    assert_nil msg.via_params
    assert_equal ["SIP/2.0/UDP host5.example.net;branch=z9hG4bKkdjuw ; Rport", "SIP/2.0/TCP 1.2.3.4;branch=z9hG4bKkdjuw"], msg.hdr_via

    assert_equal msg.cseq, 234234
    assert_equal msg.max_forwards, 87
    assert_equal msg.content_length, 150
    assert_equal msg.body.bytesize, 150

    assert_equal "sip:sips%3auser%40example.com@example.net.;transport=tcp;foo=baz?subject=lalala", msg.ruri.uri.downcase
    assert_equal :sip, msg.ruri.scheme
    assert_equal "sips:user@example.com", msg.ruri.user
    assert_equal "example.net", msg.ruri.host
    assert_equal :domain, msg.ruri.host_type
    assert_nil msg.ruri.port
    assert_equal({"transport" => "tcp", "foo" => "baz"}, msg.ruri.params)
    assert_equal "?Subject=lalala", msg.ruri.headers
    assert_equal :tcp, msg.ruri.transport_param
    assert_nil msg.ruri.phone_context_param

    assert_equal :sips, msg.from.scheme
    assert_equal "I have spaces", msg.from.user
    assert OverSIP::Utils.compare_ips("[2001:123:ab::123]", msg.from.host)
    assert_equal :ipv6_reference, msg.from.host_type
    assert_equal 9999, msg.from.port
    assert_equal({}, msg.from.params)
    assert_equal "938", msg.from_tag

    assert_equal :tel, msg.to.scheme
    assert_equal "+34944994422", msg.to.user
    assert_nil msg.to.host
    assert_nil msg.to.port
    assert_equal({"lalala" => "lololo"}, msg.to.params)
    assert_nil msg.to_tag

    assert_equal :sip, msg.contact.scheme
    assert_equal "caller", msg.contact.user
    assert_equal "host5.example.net", msg.contact.host
    assert_equal :domain, msg.contact.host_type
    assert_nil msg.contact.port
    assert_true msg.contact.ob_param?
    assert_equal({"%6c%72" => nil, "n%61me" => "v%61lue%25%34%31", "ob" => nil}, msg.contact.params)
    assert_equal ";p1=foo;P2=BAR;+sip-instance=qweqwe;reg-id=1", msg.contact_params
    assert_true msg.contact_reg_id?

    assert_equal 2, msg.routes.size

    assert_nil msg.routes.first.display_name
    assert_equal :sip, msg.routes.first.scheme
    assert_equal "qweqwe/.+asdasd", msg.routes.first.user
    assert OverSIP::Utils.compare_ips("1.2.3.4", msg.routes.first.host)
    assert_equal "1.2.3.4", msg.routes.first.host
    assert_equal :ipv4, msg.routes.first.host_type
    assert_equal 7777, msg.routes.first.port
    assert_true msg.routes.first.lr_param?

    assert_equal "Server Ñ€áéíóú", msg.routes[1].display_name
    assert_equal :sip, msg.routes[1].scheme
    assert_nil msg.routes[1].user
    assert OverSIP::Utils.compare_ips("[1::a0f]", msg.routes[1].host)
    assert_equal :ipv6_reference, msg.routes[1].host_type
    assert_equal 6666, msg.routes[1].port
    assert_true msg.routes[1].lr_param?

    assert_equal ["aaa", "bbb", "ccc"], msg.require
    assert_equal ["aaa", "bbb", "ccc"], msg.proxy_require
    assert_equal ["aaa", "bbb", "ccc"], msg.supported

    # Change the full RURI and test again.
    msg.ruri = ::OverSIP::SIP::Uri.new :sips, "iñaki", "aliax.net", 7070

    assert_equal :sips, msg.ruri.scheme
    assert_equal "iñaki", msg.ruri.user
    assert_equal "aliax.net", msg.ruri.host
    assert_equal :domain, msg.ruri.host_type
    assert_equal 7070, msg.ruri.port
    assert_equal({}, msg.ruri.params)
    assert_nil msg.ruri.headers
    assert_nil msg.ruri.transport_param
    assert_nil msg.ruri.phone_context_param
    assert_equal "sips:i%C3%B1aki@aliax.net:7070", msg.ruri.to_s
  end

end
