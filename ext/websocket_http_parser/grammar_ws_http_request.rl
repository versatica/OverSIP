%%{
  machine grammar_ws_http_request;

  include grammar_ws_http_core  "grammar_ws_http_core.rl";
  include grammar_ws_http_headers  "grammar_ws_http_headers.rl";

  path                  = pchar+ ( "/" pchar* )*;
  query                 = ( uchar | reserved )*;
  param                 = ( pchar | "/" )*;
  params                = param ( ";" param )*;
  rel_path              = path? (";" params)? %request_path ("?" %start_query query %query)?;
  absolute_path         = "/"+ rel_path;
  path_uri              = absolute_path > mark %request_uri;
  Absolute_URI          = ( "http"i %uri_is_http | "https"i %uri_is_https ) %uri_scheme "://"
                          userinfo
                          host >mark %host ( ":" port >mark %port )?
                          path_uri;
  Request_URI           = ((absolute_path | "*") >mark %request_uri) | Absolute_URI;
  Fragment              = ( uchar | reserved )* >mark %fragment;

  Method                = ( "GET"         %method_GET |
                            "POST"        %method_POST |
                            "OPTIONS"     %method_OPTIONS |
                            token ) >mark %method_unknown;

  HTTP_Version          = "HTTP"i "/" DIGIT{1,2} "." DIGIT{1,2};

  Request_Line          = Method %req_method SP
                          Request_URI ("#" Fragment)? SP
                          HTTP_Version >mark %http_version;

  Request               = Request_Line :> CRLF
                          ( Header CRLF )*
                          CRLF >write_hdr_value @done;

  main                 := Request;
}%%
