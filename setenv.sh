#!/bin/bash

export TARGET=arm-apple-darwin
export PREFIX=/usr/$TARGET
export DARWIN_PREFIX=$PREFIX

echo "Target: $TARGET"
echo "Prefix: $PREFIX"

[ -e "$PREFIX" ] \
  || mkdir -p "$PREFIX" \
  || echo "** ERROR: Failed to create \"$PREFIX\" !"

export PATH="$PATH:/usr/$TARGET/usr/bin"
