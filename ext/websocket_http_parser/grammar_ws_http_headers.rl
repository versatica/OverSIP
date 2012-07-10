%%{
  machine grammar_ws_http_headers;

  DefinedHeader               = "Content-Length"i |
                                "Host"i |
                                "Connection"i |
                                "Upgrade"i |
                                # NOTE: After draft-ietf-hybi-thewebsocketprotocol-13, "Sec-WebSocket-Origin"
                                # becomes just "Origin" (as in HTTP).
                                "Origin"i | "Sec-WebSocket-Origin"i |
                                "Sec-WebSocket-Version"i |
                                "Sec-WebSocket-Key"i |
                                "Sec-WebSocket-Protocol"i;

  generic_hdr_name            = ( token - DefinedHeader ) >write_hdr_value >start_hdr_field %write_hdr_field;
  generic_hdr_value           = ( TEXT_UTF8char | UTF8_CONT | LWS )* >start_hdr_value %store_hdr_value;
  GenericHeader               = generic_hdr_name HCOLON generic_hdr_value;

  ### Content-Length
  content_length_value        = DIGIT{1,9} >mark %content_length;
  Content_Length              = "Content-Length"i >write_hdr_value >start_hdr_field %write_hdr_field
                                HCOLON content_length_value >start_hdr_value %store_hdr_value;

  ### Host
  host_value                  = host >mark %host ( ":" port >mark %port )?;
  Host                        = "Host"i >write_hdr_value >start_hdr_field %write_hdr_field
                                HCOLON host_value >start_hdr_value %store_hdr_value;

  ### Connection
  connection_value            = token >mark %hdr_connection_value;
  Connection                  = ( "Connection"i ) >write_hdr_value >start_hdr_field %write_hdr_field HCOLON
                                ( connection_value >start_hdr_value
                                ( COMMA connection_value )* ) %store_hdr_value;

  ### Upgrade
  upgrade_value               = token >mark %hdr_upgrade;
  Upgrade                     = "Upgrade"i >write_hdr_value >start_hdr_field %write_hdr_field
                                HCOLON upgrade_value >start_hdr_value %store_hdr_value;

  ### Origin
  origin_value                = PRINTABLE_ASCII+ >mark %hdr_origin;
  Origin                      = ( "Origin"i | "Sec-WebSocket-Origin"i ) >write_hdr_value >start_hdr_field %write_hdr_field
                                HCOLON origin_value >start_hdr_value %store_hdr_value;

  ### Sec-WebSocket-Version
  sec_websocket_version_value = DIGIT{1,3} >mark %hdr_sec_websocket_version;
  Sec_WebSocket_Version       = "Sec-WebSocket-Version"i >write_hdr_value >start_hdr_field %write_hdr_field
                                HCOLON sec_websocket_version_value >start_hdr_value %store_hdr_value;

  ### Sec-WebSocket-Key
  sec_websocket_key_value     = PRINTABLE_ASCII{1,50} >mark %hdr_sec_websocket_key;
  Sec_WebSocket_Key           = "Sec-WebSocket-Key"i >write_hdr_value >start_hdr_field %write_hdr_field
                                HCOLON sec_websocket_key_value >start_hdr_value %store_hdr_value;

  ### Sec-WebSocket-Protocol
  sec_websocket_protocol_value = token >mark %hdr_sec_websocket_protocol_value;
  Sec_WebSocket_Protocol      = ( "Sec-WebSocket-Protocol"i ) >write_hdr_value >start_hdr_field %write_hdr_field HCOLON
                                ( sec_websocket_protocol_value >start_hdr_value 
                                ( COMMA sec_websocket_protocol_value )* ) %store_hdr_value;

  Header                      = GenericHeader |
                                Content_Length |
                                Host |
                                Connection |
                                Upgrade |
                                Origin |
                                Sec_WebSocket_Version |
                                Sec_WebSocket_Key |
                                Sec_WebSocket_Protocol;
}%%