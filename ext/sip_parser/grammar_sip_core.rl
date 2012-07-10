%%{
  machine grammar_sip_core;

  CRLF                        = "\r\n";
  DIGIT                       = "0".."9";
  ALPHA                       = "a".."z" | "A".."Z";
  HEXDIG                      = DIGIT | "A"i | "B"i | "C"i | "D"i | "E"i | "F"i;
  DQUOTE                      = "\"";
  SP                          = " ";
  HTAB                        = "\t";
  WSP                         = SP | HTAB;
  LWS                         = ( WSP* CRLF )? WSP+;
  SWS                         = LWS?;
  OCTET                       = 0x00..0xff;
  VCHAR                       = 0x21..0x7e;
  HCOLON                      = ( SP | HTAB )* ":" SWS;
  SEMI                        = SWS ";" SWS;
  EQUAL                       = SWS "=" SWS;
  SLASH                       = SWS "/" SWS;
  COLON                       = SWS ":" SWS;
  COMMA                       = SWS "," SWS;
  RAQUOT                      = ">" SWS;
  LAQUOT                      = SWS "<";
  UTF8_CONT                   = 0x80..0xbf;
  UTF8_NONASCII               = ( 0xc0..0xdf UTF8_CONT ) | ( 0xe0..0xef UTF8_CONT{2} ) | ( 0xf0..0xf7 UTF8_CONT{3} ) |
                                ( 0xf8..0xfb UTF8_CONT{4} ) | ( 0xfc..0xfd UTF8_CONT{5} );
  # NOTE: Workaround to relax grammar:
  #   https://lists.cs.columbia.edu/pipermail/sip-implementors/2010-December/026127.html
  # NOTE: This allows non UTF-8 symbols in headers!
  #UTF8_NONASCII               = 0x80..0xff;
  # NOTE: Added by me (doesn't include space neither tabulator).
  PRINTABLE_ASCII             = 0x21..0x7e;
  TEXT_UTF8char               = PRINTABLE_ASCII | UTF8_NONASCII;

  alphanum                    = ALPHA | DIGIT;
  reserved                    = ";" | "/" | "?" | ":" | "@" | "&" | "=" | "+" | "$" | ",";
  mark                        = "-" | "_" | "." | "!" | "~" | "*" | "'" | "(" | ")";
  unreserved                  = alphanum | mark;
  escaped                     = "%" HEXDIG HEXDIG;

  token                       = ( alphanum | "-" | "." | "!" | "%" | "*" | "_" | "+" | "`" | "'" | "~" )+;
  word                        = ( alphanum | "-" | "." | "!" | "%" | "*" | "_" | "+" | "`" | "'" | "~" | "(" | ")" |
                                "<" | ">" | ":" | "\\" | DQUOTE | "/" | "[" | "]" | "?" | "{" | "}" )+;
  ctext                       = 0x21..0x27 | 0x2a..0x5b | 0x5d..0x7e | UTF8_NONASCII | LWS;
  quoted_pair                 = "\\" ( 0x00..0x09 | 0x0b..0x0c | 0x0e..0x7f );
  comment                     = SWS "(" ( ctext | quoted_pair | "(" | ")" )* ")" SWS ;
  qdtext                      = LWS | "!" | 0x23..0x5b | 0x5d..0x7e | UTF8_NONASCII;
  quoted_string               = DQUOTE ( qdtext | quoted_pair )* DQUOTE;

  domainlabel                  = alphanum | ( alphanum ( alphanum | "-" | "_" )* alphanum );
  toplabel                     = ALPHA | ( ALPHA ( alphanum | "-" | "_" )* alphanum );
  hostname                     = ( domainlabel "." )* toplabel "."?;
  dec_octet                    = DIGIT | ( 0x31..0x39 DIGIT ) | ( "1" DIGIT{2} ) |
                                 ( "2" 0x30..0x34 DIGIT ) | ( "25" 0x30..0x35 );
  IPv4address                  = dec_octet "." dec_octet "." dec_octet "." dec_octet;
  h16                          = HEXDIG{1,4};
  ls32                         = ( h16 ":" h16 ) | IPv4address;
  IPv6address                  = ( ( h16 ":" ){6} ls32 ) |
                                 ( "::" ( h16 ":" ){5} ls32 ) |
                                 ( h16? "::" ( h16 ":" ){4} ls32 ) |
                                 ( ( ( h16 ":" )? h16 )? "::" ( h16 ":" ){3} ls32 ) |
                                 ( ( ( h16 ":" ){,2} h16 )? "::" ( h16 ":" ){2} ls32 ) |
                                 ( ( ( h16 ":" ){,3} h16 )? "::" h16 ":" ls32 ) |
                                 ( ( ( h16 ":" ){,4} h16 )? "::" ls32 ) |
                                 ( ( ( h16 ":" ){,5} h16 )? "::" h16 ) |
                                 ( ( ( h16 ":" ){,6} h16 )? "::" );
  IPv6reference                = "[" IPv6address "]";
  host                         = hostname |
                                 IPv4address |
                                 IPv6reference;
  #port                        = DIGIT{1,5};
  # Valid values: 0 - 65535.
  port                       = ( DIGIT{1,4} |
                                 "1".."5" DIGIT{4} |
                                 "6" "0".."4" DIGIT{3} |
                                 "6" "5" "0".."4" DIGIT{2} |
                                 "6" "5" "5" "0".."2" DIGIT |
                                 "6" "5" "5" "3" "0".."5"
                               ) - ( "0" | "00" | "000" | "0000" );
  hostport                    = host ( ":" port )?;

  user_unreserved             = "&" | "=" | "+" | "$" | "," | ";" | "?" | "/";
  # NOTE: '#' allowed even if it's incorrect.
  user                        = ( user_unreserved | unreserved | escaped | "#" )+;
  password                    = ( unreserved | escaped | "&" | "=" | "+" | "$" | "," )*;
  userinfo                    = user ( ":" password )?;
}%%