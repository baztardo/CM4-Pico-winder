#!/bin/sh
# This script checks for a broken Ubuntu 18.04 arm-none-eabi-gcc compile

f1="$1"
f2="$2"

# Try to find readelf in common locations
READELF=""
for path in "/opt/homebrew/opt/binutils/bin/readelf" "/usr/bin/readelf" "/usr/local/bin/readelf" "readelf"; do
    if command -v "$path" >/dev/null 2>&1; then
        READELF="$path"
        break
    fi
done

if [ -z "$READELF" ]; then
    echo "Warning: readelf not found, skipping compiler check"
    exit 0
fi

s1=`"$READELF" -A "$f1" | grep "Tag_ARM_ISA_use"`
s2=`"$READELF" -A "$f2" | grep "Tag_ARM_ISA_use"`

if [ "$s1" != "$s2" ]; then
    echo ""
    echo "ERROR: The compiler failed to correctly compile Klipper"
    echo "It will be necessary to upgrade the compiler"
    echo "See: https://bugs.launchpad.net/ubuntu/+source/newlib/+bug/1767223"
    echo ""
    rm -f "$f1"
    exit 99
fi
