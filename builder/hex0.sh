#!/bin/sh

sed 's/[;#].*$//g' $1 | xxd -r -p > $2
