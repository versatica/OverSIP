%%{
  machine grammar_ip;

  DIGIT                         = "0".."9";
  HEXDIG                        = DIGIT | "A"i | "B"i | "C"i | "D"i | "E"i | "F"i;
  dec_octet                     = DIGIT | ( 0x31..0x39 DIGIT ) | ( "1" DIGIT{2} ) |
                                  ( "2" 0x30..0x34 DIGIT ) | ( "25" 0x30..0x35 );
  IPv4address                   = dec_octet "." dec_octet "." dec_octet "." dec_octet;
  h16                           = HEXDIG{1,4};
  ls32                          = ( h16 ":" h16 ) | IPv4address;
  IPv6address                   = ( ( h16 ":" ){6} ls32 ) |
                                  ( "::" ( h16 ":" ){5} ls32 ) |
                                  ( h16? "::" ( h16 ":" ){4} ls32 ) |
                                  ( ( ( h16 ":" )? h16 )? "::" ( h16 ":" ){3} ls32 ) |
                                  ( ( ( h16 ":" ){,2} h16 )? "::" ( h16 ":" ){2} ls32 ) |
                                  ( ( ( h16 ":" ){,3} h16 )? "::" h16 ":" ls32 ) |
                                  ( ( ( h16 ":" ){,4} h16 )? "::" ls32 ) |
                                  ( ( ( h16 ":" ){,5} h16 )? "::" h16 ) |
                                  ( ( ( h16 ":" ){,6} h16 )? "::" );

  port                          = ( DIGIT{1,4} |
                                  "1".."5" DIGIT{4} |
                                  "6" "0".."4" DIGIT{3} |
                                  "6" "5" "0".."4" DIGIT{2} |
                                  "6" "5" "5" "0".."2" DIGIT |
                                  "6" "5" "5" "3" "0".."5"
                                  ) - ( "0" | "00" | "000" | "0000" );
}%%