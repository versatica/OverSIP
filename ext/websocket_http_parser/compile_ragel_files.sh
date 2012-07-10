#!/bin/bash


which ragel >/dev/null
if [ $? -ne 0 ] ; then
  echo "ERROR: ragel binary not found, cannot compile the Ragel grammar." >&2
  exit 1
else
  ragel -v
  echo
fi


set -e

RAGEL_FILE=ws_http_parser
echo "DEBUG: compiling Ragel grammar $RAGEL_FILE.rl ..."
ragel -T0 -C $RAGEL_FILE.rl
echo
echo "DEBUG: $RAGEL_FILE.c generated"
echo
