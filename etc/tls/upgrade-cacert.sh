#!/bin/bash

# This script downloads the Root CAs list from Mozilla and stores
# it under ca/ directory for TLS validation.
# cacert.pem is downloaded from http://curl.haxx.se/docs/caextract.html
# (the exact link is http://curl.haxx.se/ca/cacert.pem).
# cacert.pem is just downloaded in case the server version is newer than
# the local version of the file.

cd ca/
wget -N http://curl.haxx.se/ca/cacert.pem

