#!/bin/bash

export TARGET=arm-apple-darwin
export PREFIX=/usr/$TARGET
export DARWIN_PREFIX=$PREFIX

export PATH="$PATH:/usr/$TARGET/usr/bin"

[ -z "$CODESIGN_ALLOCATE" ] && export CODESIGN_ALLOCATE="${TARGET}-codesign_allocate"

[ -e "$PREFIX" ] \
  || mkdir -p "$PREFIX" \
  || echo "** ERROR: Failed to create \"$PREFIX\" !"

echo "Target: $TARGET"
echo "Prefix: $PREFIX"
echo "CODESIGN_ALLOCATE: $CODESIGN_ALLOCATE"
