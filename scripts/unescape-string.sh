#!/bin/bash

# unescape-string.sh
# Convert escaped strings (\n, \", etc.) to actual characters
# Reads from stdin, writes to stdout

sed -e 's/\\n/\n/g' \
    -e 's/\\"/"/g' \
    -e 's/\\\\/\\/g' \
    -e 's/\\t/\t/g' \
    -e 's/\\r/\r/g'
