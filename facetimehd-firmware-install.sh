#!/bin/bash

# SPDX-License-Identifier: GPL-2.0-only

# This is a simplified version of the download/extract/install scripts
# It is intended to be used by disto package installs (e.g. in %post stage)

URL=https://updates.cdn-apple.com/2019/cert/041-88431-20191011-e7ee7d98-2878-4cd9-bc0a-d98b3a1e24b1/OSXUpd10.11.5.dmg
RANGE=204909802-207733123
OSX_DRV=AppleCameraInterface
OSX_DRV_DIR=System/Library/Extensions/AppleCameraInterface.kext/Contents/MacOS
FILE=$OSX_DRV_DIR/$OSX_DRV
DRV_HASH=f56e68a880b65767335071531a1c75f3cfd4958adc6d871adf8dbf3b788e8ee1
FW_HASH=e3e6034a67dfdaa27672dd547698bbc5b33f47f1fc7f5572a2fb68ea09d32d3d
OFFSET=81920
SIZE=603715

if [[ "$EUID" != 0 ]]
	then echo "Please run as root"
	exit 1
fi

echo -e "FacetimeHD firmware download and installation script\n"

echo -n "Downloading driver..."
cd /tmp
curl -s -L -r "$RANGE" "$URL" | xzcat -q  2> /dev/null | cpio --format odc -i -d "./$FILE" &> /dev/null
mv $FILE .
rm -R ./System
echo "done"

HASH=$(sha256sum $OSX_DRV | awk '{ print $1 }')
if [[ "$HASH" != "$DRV_HASH" ]]; then
	echo "Incorrect driver checksum. Aborting."
	exit 1
fi

echo -n "Extracting firmware..."
dd bs=1 skip=$OFFSET count=$SIZE if=./$OSX_DRV of=./firmware.bin.gz &> /dev/null
rm ./$OSX_DRV
gunzip ./firmware.bin.gz
echo "done"
HASH=$(sha256sum ./firmware.bin | awk '{ print $1 }')
if [[ "$HASH" != "$FW_HASH" ]]; then
	echo "Incorrect firmware checksum. Aborting."
	exit 1
fi

echo -n "Installing firmware..."
if [ -d "/usr/lib/firmware" ]; then
	FW_DIR=/usr/lib/firmware/facetimehd
else
	FW_DIR=/lib/firmware/facetimehd
fi

install -dm755 $FW_DIR
install -m644 firmware.bin $FW_DIR/firmware.bin
rm firmware.bin
echo "done"
