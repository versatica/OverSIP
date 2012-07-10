%%{
  machine grammar_sip_message;

  include grammar_sip_core    "grammar_sip_core.rl";

  Method                      = ( "INVITE"      %msg_method_INVITE |
                                  "ACK"         %msg_method_ACK |
                                  "CANCEL"      %msg_method_CANCEL |
                                  "PRACK"       %msg_method_PRACK |
                                  "BYE"         %msg_method_BYE |
                                  "REFER"       %msg_method_REFER |
                                  "INFO"        %msg_method_INFO |
                                  "UPDATE"      %msg_method_UPDATE |
                                  "OPTIONS"     %msg_method_OPTIONS |
                                  "REGISTER"    %msg_method_REGISTER |
                                  "MESSAGE"     %msg_method_MESSAGE |
                                  "SUBSCRIBE"   %msg_method_SUBSCRIBE |
                                  "NOTIFY"      %msg_method_NOTIFY |
                                  "PUBLISH"     %msg_method_PUBLISH |
                                  "PULL"        %msg_method_PULL |
                                  "PUSH"        %msg_method_PUSH |
                                  "STORE"       %msg_method_STORE |
                                  token ) >mark %msg_method_unknown;

  include grammar_sip_uri       "grammar_sip_uri.rl";
  include grammar_tel_uri       "grammar_tel_uri.rl";
  include grammar_absolute_uri  "grammar_absolute_uri.rl";
  include grammar_name_addr     "grammar_name_addr.rl";
  include grammar_sip_headers   "grammar_sip_headers.rl";

  ### TODO: Quitar el HTTP
  SIP_Version                 = ( "SIP"i | "HTTP"i ) "/" DIGIT{1,2} "." DIGIT{1,2};

  # In request.
  Request_Line                = Method %msg_request %msg_method SP >init_ruri
                                ( SIP_URI | TEL_URI | absoluteURI ) >do_request_uri SP
                                SIP_Version >mark %msg_sip_version;

  # In response.
  Status_Code                 = ( "1".."6" DIGIT{2} ) >mark %msg_status_code;
  Reason_Phrase               = ( ( any )* -- CRLF ) >mark %msg_reason_phrase;
  Status_Line                 = SIP_Version %msg_response >mark %msg_sip_version SP
                                Status_Code SP Reason_Phrase;

  SIP_Message                 = ( Request_Line :> CRLF | Status_Line :> CRLF )
                                ( Header CRLF )*
                                CRLF >write_hdr_value @done;

  Outbound_keepalive               = ( CRLF CRLF ) @outbound_keepalive @done;

  main                       := ( CRLF? SIP_Message ) | Outbound_keepalive;
}%%
