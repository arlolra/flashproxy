#!/bin/bash
# Wrapper around help2man that takes input from stdin.

set -o errexit

# Read a python program's description from the first paragraph of its docstring.
get_description() {
	PYTHONPATH=".:$PYTHONPATH" python - "./$1" <<EOF
import imp, sys
sys.dont_write_bytecode = True
mod = imp.load_source("mod", sys.argv[1])
doclines = mod.__doc__.splitlines()
# skip to start of first paragraph
while not doclines[0]:
    doclines.pop(0)
# find where the paragraph ends
try:
    r = doclines.index("")
except ValueError:
    r = len(doclines)
print " ".join(doclines[:r]).strip()
EOF
}

# Fixes some help2man quirks, see `man man`
help2man_fixup() {
	sed -re '
# restricted to usage synopsis section
/^\.SH SYNOPSIS$/,/^\.SH \w+$/{
	# change hypenated parameters to bold, "type exactly as shown"
	s/\\fI\-/\\fB\-/g;
	# change ALL-CAPS parameters to italic, "replace with appropriate argument"
	s/\b([A-Z]+)\b/\\fI\1\\fR/g;
}'
}

prog="$1"
ver="$2"
name="${3:-$(get_description "$1")}"

# Prepare a temporary executable file that just dumps its own contents.
trap 'rm -rf .tmp.$$' EXIT INT TERM
shebang="#!/usr/bin/tail -n+2"
mkdir -p ".tmp.$$"
{
echo "$shebang"
cat
} > ".tmp.$$/$prog"
test $(stat -c "%s" ".tmp.$$/$prog") -gt $((${#shebang} + 1)) || { echo >&2 "no input received; abort"; exit 1; }
chmod +x ".tmp.$$/$prog"

help2man ".tmp.$$/$prog" --help-option="-q" \
  --name="$name" --version-string="$ver" \
  --no-info --include "$(dirname "$0")/mkman.inc" \
  | help2man_fixup
