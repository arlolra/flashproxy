#!/bin/sh
# Read version from the ChangeLog to avoid repeating in multiple build scripts
sed -ne 's/^Changes .* version \(..*\)$/\1/g;tx;b;:x p;q' ChangeLog
