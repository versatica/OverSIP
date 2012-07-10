%%{
  machine grammar_name_addr;

  uri_display_name           = ( quoted_string >uri_display_name_quoted | ( token ( LWS token )* ) );
  addr_spec                  = SIP_URI | TEL_URI | absoluteURI;
  name_addr                  = ( uri_display_name >mark %uri_display_name )? LAQUOT addr_spec RAQUOT;

  # It solves a problem when multiples name_addr are allowed separated by COMMA (i.e. Contact header).
  name_addr_anti_COMMA       = ( uri_display_name >mark %uri_display_name )? LAQUOT addr_spec ">";

  # In Route header just SIP/SIPS schemes are allowed. It also allows comma separated values, so apply
  # same as in name_addr_anti_COMMA.
  name_addr_sip              = ( uri_display_name >mark %uri_display_name )? LAQUOT SIP_URI ">";
}%%