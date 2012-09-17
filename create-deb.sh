#!/bin/bash

# Using this the generated stuf is clean after package is built.
# Options -us and -uc prevent the package from being signed.
dpkg-buildpackage -tc -us -uc

# Similar option. The second command cleans the generated stuf.
#debuild -us -uc
#./debian/rules clean

# Clean debian/files and the log file.
rm -f debian/files
rm -f debian/oversip.debhelper.log

