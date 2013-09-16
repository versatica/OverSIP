# coding: utf-8

#
# OverSIP - Server Logic.
#




### Custom Application Code:


# Define here your custom code for the application running on top of OverSIP.
# Here you can load thirdy-party libraries and so on.
#
# require "some-gem"
#
module MyExampleApp
  extend ::OverSIP::Logger

  class << self
    attr_reader :do_outbound_mangling, :do_user_assertion
  end

  # Set this to _true_ if the SIP registrar behind OverSIP does not support Path.
  # OverSIP::Modules::OutboundMangling methods will be used.
  @do_outbound_mangling = true

  # Set this to _true_ if the SIP proxy/server behind OverSIP performing the authentication
  # is ready to accept a P-Asserted-Identity header from OverSIP indicating the already
  # asserted SIP user of the client's connection (this avoids authenticating all the requests
  # but the first one).
  # OverSIP::Modules::UserAssertion methods will be used.
  @do_user_assertion = true
end




### OverSIP System Events:


# This method is called when the main configuration files have been loaded.
# Place here 3rd party modules initializer code.
# This method is not executed again when OverSIP is reloaded (HUP signal).
#
# def (OverSIP::SystemEvents).on_initialize
#   [...]
# end


# This method is called once the OverSIP reactor has been started.
#
# def (OverSIP::SystemEvents).on_started
#   [...]
# end


# This method is called when a USR1 signal is received by OverSIP main
# process and allows the user to set custom code to be executed
# or reloaded.
#
# def (OverSIP::SystemEvents).on_user_reload
#   [...]
# end


# This method is called after OverSIP has been terminated. It's called
# with argument "error" which is _true_ in case OverSIP has died in an
# unexpected way.
#
# def (OverSIP::SystemEvents).on_terminated error
#   [...]
# end




### OverSIP SIP Events:


# This method is called when a SIP request is received.
#
def (OverSIP::SipEvents).on_request request

  log_info "#{request.sip_method} from #{request.from.uri} (UA: #{request.header("User-Agent")}) to #{request.ruri} via #{request.transport.upcase} #{request.source_ip} : #{request.source_port}"

  # Check Max-Forwards value (max 10).
  return unless request.check_max_forwards 10

  # Assume all the traffic is from clients and help them with NAT issues
  # by forcing rport usage and Outbound mechanism.
  request.fix_nat

  # In-dialog requests.
  if request.in_dialog?
    if request.loose_route
      log_debug "proxying in-dialog #{request.sip_method}"
      proxy = ::OverSIP::SIP::Proxy.new :proxy_in_dialog
      proxy.route request
    else
      unless request.sip_method == :ACK
        log_notice "forbidden in-dialog request without top Route pointing to us => 403"
        request.reply 403, "forbidden in-dialog request without top Route pointing to us"
      else
        log_notice "ignoring not loose routing ACK"
      end
    end
    return
  end

  # Initial requests.

  # Check that the request does not contain a top Route pointing to another server.
  if request.loose_route
    unless request.sip_method == :ACK
      log_notice "pre-loaded Route not allowed here => 403"
      request.reply 403, "Pre-loaded Route not allowed"
    else
      log_notice "ignoring ACK initial request"
    end
    return
  end

  if MyExampleApp.do_outbound_mangling
    # Extract the Outbound flow token from the RURI.
    ::OverSIP::Modules::OutboundMangling.extract_outbound_from_ruri request
  end

  # The request goes to a client using Outbound through OverSIP.
  if request.incoming_outbound_requested?
    log_info "routing initial request to an Outbound client"

    proxy = ::OverSIP::SIP::Proxy.new :proxy_to_users

    proxy.on_success_response do |response|
      log_info "incoming Outbound on_success_response: #{response.status_code} '#{response.reason_phrase}'"
    end

    proxy.on_failure_response do |response|
      log_info "incoming Outbound on_failure_response: #{response.status_code} '#{response.reason_phrase}'"
    end

    # on_error() occurs when no SIP response was received fom the peer and, instead, we
    # got some other internal error (timeout, connection error, DNS error....).
    proxy.on_error do |status, reason|
      log_notice "incoming Outbound on_error: #{status} '#{reason}'"
    end

    # Route the request and return.
    proxy.route request
    return
  end

  # An initial request with us (OverSIP) as final destination, ok, received, bye...
  if request.destination_myself?
    log_info "request for myself => 404"
    request.reply 404, "Ok, I'm here"
    return
  end

  # An outgoing initial request.
  case request.sip_method

  when :INVITE, :MESSAGE, :OPTIONS, :SUBSCRIBE, :PUBLISH, :REFER

    if MyExampleApp.do_user_assertion
      ::OverSIP::Modules::UserAssertion.add_pai request
    end

    proxy = ::OverSIP::SIP::Proxy.new :proxy_out

    proxy.on_provisional_response do |response|
      log_info "on_provisional_response: #{response.status_code} '#{response.reason_phrase}'"
    end

    proxy.on_success_response do |response|
      log_info "on_success_response: #{response.status_code} '#{response.reason_phrase}'"
    end

    proxy.on_failure_response do |response|
      log_info "on_failure_response: #{response.status_code} '#{response.reason_phrase}'"
    end

    proxy.on_error do |status, reason|
      log_notice "on_error: #{status} '#{reason}'"
    end

    proxy.on_invite_timeout do
      log_notice "INVITE timeout, no final response before Timer C expires."
    end

    proxy.route request
    return

  when :REGISTER

    proxy = ::OverSIP::SIP::Proxy.new :proxy_out

    if MyExampleApp.do_outbound_mangling
      # Contact mangling for the case in which the registrar does not support Path.
      ::OverSIP::Modules::OutboundMangling.add_outbound_to_contact proxy
    end

    proxy.on_success_response do |response|
      if MyExampleApp.do_user_assertion
        # The registrar replies 200 after a REGISTER with credentials so let's assert
        # the current SIP user to this connection.
        ::OverSIP::Modules::UserAssertion.assert_connection response
      end
    end

    proxy.on_failure_response do |response|
      if MyExampleApp.do_user_assertion
        # We don't add PAI for re-REGISTER, so 401 will be replied, and after it let's
        # revoke the current user assertion (will be re-added upon REGISTER with credentials).
        ::OverSIP::Modules::UserAssertion.revoke_assertion response
      end
    end

    proxy.route request
    return

  else

    log_info "method #{request.sip_method} not implemented => 501"
    request.reply 501, "Not Implemented"
    return

  end

end


# This method is called when a client initiates a SIP TLS handshake.
def (OverSIP::SipEvents).on_client_tls_handshake connection, pems

  log_info "validating TLS connection from IP #{connection.remote_ip} and port #{connection.remote_port}"

  cert, validated, tls_error, tls_error_string = ::OverSIP::TLS.validate pems
  identities = ::OverSIP::TLS.get_sip_identities cert

  if validated
    log_info "client provides a valid TLS certificate with SIP identities #{identities}"
  else
    log_notice "client provides an invalid TLS certificate with SIP identities #{identities} (TLS error: #{tls_error.inspect}, description: #{tls_error_string.inspect})"
    #connection.close
  end

end


# This method is called when conntacting a SIP TLS server and the TLS handshake takes place.
def (OverSIP::SipEvents).on_server_tls_handshake connection, pems

  log_info "validating TLS connection to IP #{connection.remote_ip} and port #{connection.remote_port}"

  cert, validated, tls_error, tls_error_string = ::OverSIP::TLS.validate pems
  identities = ::OverSIP::TLS.get_sip_identities cert

  if validated
    log_info "server provides a valid TLS certificate with SIP identities #{identities}"
  else
    log_notice "server provides an invalid TLS certificate with SIP identities #{identities} (TLS error: #{tls_error.inspect}, description: #{tls_error_string.inspect})"
    #connection.close
  end

end




### OverSIP WebSocket Events:


# This method is called when a new WebSocket connection is being requested.
# Here you can inspect the connection and the HTTP GET request. If you
# decide not to accept this connection then call to:
#
#   connection.http_reject(status_code, reason_phrase=nil, extra_headers=nil)
#
# You can also set variables for this connection via the connection.cvars
# Hash. Later you can access to this Hash in SIP requests from this connection
# by retrieving request.cvars attribute.
#
# def (OverSIP::WebSocketEvents).on_connection connection, http_request
#   [...]
# end


# This method is called when a WebSocket connection is closed. The connection
# is given as first argument along with a second argument "client_closed" which
# is _true_ in case the WebSocket connection was closed by the client.
#
# def (OverSIP::WebSocketEvents).on_disconnection connection, client_closed
#   [...]
# end


# This method is called when a client initiates a WebSocket TLS handshake.
def (OverSIP::WebSocketEvents).on_client_tls_handshake connection, pems

  log_info "validating TLS connection from IP #{connection.remote_ip} and port #{connection.remote_port}"

  cert, validated, tls_error, tls_error_string = ::OverSIP::TLS.validate pems
  identities = ::OverSIP::TLS.get_sip_identities cert

  if validated
    log_info "client provides a valid TLS certificate with SIP identities #{identities}"
  else
    log_notice "client provides an invalid TLS certificate with SIP identities #{identities} (TLS error: #{tls_error.inspect}, description: #{tls_error_string.inspect})"
    #connection.close
  end

end
