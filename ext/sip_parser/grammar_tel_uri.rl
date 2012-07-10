%%{
  machine grammar_tel_uri;

  tel_visual_separator        = "-" | "." | "(" | ")";
  tel_phonedigit              = DIGIT | tel_visual_separator;
  tel_global_number_digits    = "+" tel_phonedigit* DIGIT tel_phonedigit*;
  tel_phonedigit_hex          = HEXDIG | "*" | "#" | tel_visual_separator;
  tel_local_number_digits     = tel_phonedigit_hex* ( HEXDIG | "*" | "#" ) tel_phonedigit_hex*;

  tel_descriptor              = hostname | tel_global_number_digits;
  tel_context                 = "phone-context="i tel_descriptor >mark %uri_tel_phone_context;

  tel_param_unreserved        = "[" | "]" | "/" | ":" | "&" | "+" | "$";
  tel_pct_encoded             = "%" HEXDIG HEXDIG;
  tel_paramchar               = tel_param_unreserved | unreserved | tel_pct_encoded;
  tel_uri_pname               = ( alphanum | "-" )+;
  tel_uri_pvalue              = tel_paramchar+;

  tel_uri_param               = ( tel_uri_pname >start_uri_param_key %uri_param_key_len
                                ( "=" tel_uri_pvalue >start_uri_param_value %uri_param_value_len )? %write_uri_param ) |
                                tel_context;

  tel_uri_params              = ( ";" tel_uri_param )*;

  tel_global_number           = tel_global_number_digits >mark %uri_user tel_uri_params;
  tel_local_number            = tel_local_number_digits >mark %uri_user tel_uri_params;

  TEL_URI                     = (
                                  "tel:"i %uri_is_tel >start_uri >mark %uri_scheme
                                  ( tel_global_number | tel_local_number )
                                ) %write_uri;
}%%