%%{
  machine grammar_sip_headers;

  DefinedHeader               = "Call-ID"i | "i"i |
                                "Contact"i | "m"i |
                                "Content-Length"i | "l"i |
                                "CSeq"i |
                                "From"i | "f"i |
                                "Max-Forwards"i |
                                "Proxy-Require"i |
                                "Require"i |
                                "Supported"i | "k"i |
                                "Route"i |
                                "To"i | "t"i |
                                "Via"i | "v"i;

  header_param_gen_value      = token | host | quoted_string;
  header_param                = token ( EQUAL header_param_gen_value )? ;

  generic_hdr_name            = ( token - DefinedHeader ) >write_hdr_value >start_hdr_field %write_hdr_field;
  generic_hdr_value           = ( TEXT_UTF8char | UTF8_CONT | LWS )* >start_hdr_value %store_hdr_value;
  GenericHeader               = generic_hdr_name HCOLON generic_hdr_value;


  ### Call-ID.
  call_id_value               = ( word ( "@" word )? ) >mark %msg_call_id;
  Call_ID                     = ( "Call-ID"i | "i"i ) >write_hdr_value >start_hdr_field %write_hdr_field
                                HCOLON >new_call_id call_id_value >start_hdr_value %store_hdr_value;

  ### Contact (just for the case in which Contact contains a single SIP URI).
  #   Contact: "Alice Ñ€€€" <sip:alice@1.2.3.4:5060;transport=udp>
  #contact_param               = token >start_header_param_key %header_param_key_len
  #                              ( EQUAL header_param_gen_value >start_header_param_value %header_param_value_len )? %write_contact_param;
  contact_param               = token ( EQUAL header_param_gen_value )?;
  contact_reg_id_param        = "reg-id"i  %contact_has_reg_id_param ( "=" token )?;
  contact_params              = ( SEMI ( contact_reg_id_param | contact_param ) )* >mark %contact_params;
  contact_value               = ( ( name_addr_sip | ( SIP_URI -- ( "," | "?" | ";" ) ) ) contact_params )
                                >start_hdr_value >do_contact_uri %contact_is_valid %store_hdr_value;
  Contact                     = ( "Contact"i | "m"i ) >write_hdr_value >start_hdr_field %write_hdr_field HCOLON
                                >new_contact >init_contact
                                ( ( contact_value (COMMA @contact_is_invalid %write_hdr_value <: contact_value >new_contact)* ) | generic_hdr_value );

  ### Content-Length.
  content_length_value        = DIGIT{1,9} >mark %msg_content_length;
  Content_Length              = ( "Content-Length"i | "l"i ) >write_hdr_value >start_hdr_field %write_hdr_field
                                HCOLON >new_content_length content_length_value >start_hdr_value %store_hdr_value;

  ### CSeq.
  #   CSeq: 4711 INVITE
  cseq_value                  = DIGIT{1,10} >mark %msg_cseq_number LWS ( Method %msg_method when ! is_method_set | token when is_method_set );
  CSeq                        = "CSeq"i >write_hdr_value >start_hdr_field %write_hdr_field HCOLON
                                >new_cseq cseq_value >start_hdr_value %store_hdr_value;

  ### From.
  #   From: "A. G. Bell" <sip:agb@bell-telephone.com> ;tag=a48s
  from_tag_param              = "tag"i EQUAL token >mark %from_tag;
  from_param                  = ( from_tag_param | token ( EQUAL header_param_gen_value )? );
  from_value                  = ( name_addr | ( addr_spec -- ( "," | "?" | ";" ) ) )
                                ( SEMI from_param )*;
  From                        = ( "From"i | "f"i ) >write_hdr_value >start_hdr_field %write_hdr_field HCOLON >init_from
                                >new_from from_value >start_hdr_value >do_from_uri %store_hdr_value;

  ### Max-Forwards.
  max_forwards_value          = DIGIT{1,4} >mark %msg_max_forwards;
  Max_Forwards                = "Max-Forwards"i >write_hdr_value >start_hdr_field %write_hdr_field HCOLON
                                >new_max_forwards max_forwards_value >start_hdr_value %store_hdr_value;

  # Option tag is used by Proxy-Require, Require and Supported headers.
  option_tag                  = token;

  ### Proxy-Require.
  Proxy_Require               = ( "Proxy-Require"i ) >write_hdr_value >start_hdr_field %write_hdr_field HCOLON
                                ( option_tag >mark %proxy_require_option_tag
                                ( COMMA option_tag >mark %proxy_require_option_tag )* ) >start_hdr_value %store_hdr_value;

  ### Require.
  Require                     = ( "Require"i ) >write_hdr_value >start_hdr_field %write_hdr_field HCOLON
                                ( option_tag >mark %require_option_tag
                                ( COMMA option_tag >mark %require_option_tag )* ) >start_hdr_value %store_hdr_value;

  ### Route.
  route_param                 = token ( EQUAL header_param_gen_value )?;
  route_value                 = ( name_addr_sip ( SEMI route_param )* ) >start_hdr_value >do_route_uri %store_hdr_value;
  Route                       = "Route"i >write_hdr_value >start_hdr_field %write_hdr_field HCOLON >init_route >init_route_uri
                                route_value ( COMMA %init_route_uri %write_hdr_value <: route_value )*;

  ### Supported.
  Supported                   = ( "Supported"i | "k"i ) >write_hdr_value >start_hdr_field %write_hdr_field HCOLON
                                ( option_tag >mark %supported_option_tag
                                ( COMMA option_tag >mark %supported_option_tag )* )? >start_hdr_value %store_hdr_value;

  ### To.
  to_tag_param                = "tag"i EQUAL token >mark %to_tag;
  to_param                    = ( to_tag_param | token ( EQUAL header_param_gen_value )? );
  to_value                    = ( name_addr | ( addr_spec -- ( "," | "?" | ";" ) ) ) ( SEMI to_param )*;
  To                          = ( "To"i | "t"i ) >write_hdr_value >start_hdr_field %write_hdr_field HCOLON >init_to
                                >new_to to_value >start_hdr_value >do_to_uri %store_hdr_value;

  ### Via.
  via_protocol_name           = "SIP"i | token;
  via_protocol_version        = token;
  via_transport               = token;
  via_sent_protocol           = via_protocol_name SLASH via_protocol_version SLASH via_transport;
  via_sent_by                 = host >mark %via_sent_by_host ( COLON port >mark %via_sent_by_port )?;
  # NOTE: By setting %via_branch_rfc3261, in case the branch is just "z9hG4bK" then the action is not executed.
  via_branch                  = "branch"i EQUAL ( ( "z9hG4bK" %via_branch_rfc3261 )? token ) >mark %via_branch;
  via_received                = "received"i EQUAL ( IPv4address | IPv6address ) >mark %via_received;
  via_rport                   = "rport"i %via_has_rport ( EQUAL port )?;
  via_alias                   = "alias"i %via_has_alias ( EQUAL token )?;
  via_other_param             = ( token - ( "branch"i | "received"i | "rport"i | "alias"i ) ) >start_header_param_key %header_param_key_len
                                ( EQUAL header_param_gen_value >start_header_param_value %header_param_value_len )? %write_via_param;
  via_param                   = ( via_branch | via_received | via_rport | via_alias | via_other_param );
  via_params                  = ( SEMI via_param )*;
  via_value                   = ( via_sent_protocol LWS via_sent_by %write_header_via_core via_params )
                                >new_via >start_hdr_value %store_hdr_value;
  Via                         = ( "Via"i | "v"i ) >write_hdr_value >start_hdr_field %write_hdr_field HCOLON
                                >init_via via_value ( COMMA %write_hdr_value via_value )*;


  Header                      = GenericHeader |
                                Call_ID |
                                Contact |
                                Content_Length |
                                CSeq |
                                From |
                                Max_Forwards |
                                Proxy_Require |
                                Require |
                                Route |
                                Supported |
                                To |
                                Via;
}%%