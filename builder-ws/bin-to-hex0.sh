#!/bin/sh

(xxd -p $1 | tr -d '\n' | fold -w8 | sed 's/\(..\)/\1 /g' | tr '[a-f]' '[A-F]' && echo) > $2

