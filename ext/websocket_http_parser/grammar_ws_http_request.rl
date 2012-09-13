%%{
  machine grammar_ws_http_request;

  include grammar_ws_http_core  "grammar_ws_http_core.rl";
  include grammar_ws_http_headers  "grammar_ws_http_headers.rl";

  path                  = pchar+ ( "/" pchar* )*;
  query                 = ( uchar | reserved )*;
  rel_path              = path? %request_path ("?" %start_query query %query)?;
  absolute_path         = "/"+ rel_path;
  Fragment              = ( uchar | reserved )* >start_fragment %fragment;
  Request_URI           = (absolute_path ("#" Fragment)?) >mark %request_uri;

  Method                = ( "GET"         %method_GET |
                            "POST"        %method_POST |
                            "OPTIONS"     %method_OPTIONS |
                            token ) >mark %method_unknown;

  HTTP_Version          = "HTTP"i "/" DIGIT{1,2} "." DIGIT{1,2};

  Request_Line          = Method %req_method SP
                          Request_URI SP
                          HTTP_Version >mark %http_version;

  Request               = Request_Line :> CRLF
                          ( Header CRLF )*
                          CRLF >write_hdr_value @done;

  main                 := Request;
}%%
