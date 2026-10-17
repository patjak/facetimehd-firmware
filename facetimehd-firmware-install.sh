#!/bin/bash

# SPDX-License-Identifier: GPL-2.0-only

# This is a simplified version of the download/extract/install scripts
# It is intended to be used by distro package installs (e.g. in %post stage)
#
# By default this installs firmware 5.60.0 plus all eleven sensor calibration
# ("set") files, both extracted from the macOS Sierra 10.12.6 combo update.
# Firmware 1.43.0 (from OS X 10.11.5) predates the 12-inch MacBook
# (MacBook8,1 / 9,1 / 10,1) and cannot detect its sensor; 5.60.0 comes from a
# macOS release that supported every FacetimeHD Mac. The set files include
# the seven that are missing from the 2014 Boot Camp driver, among them
# 1675_01XX.dat, which the 12-inch MacBook needs.
#
# Options:
#   --osx-10.11.5    install firmware 1.43.0 from OS X 10.11.5 instead
#                    (the previous default; provides no set files)
#   --no-setfiles    do not install the sensor set files
#
# Instead of fetching the whole 1.9 GB update, only the pbzx chunks (each a
# complete xz stream) that contain the camera binaries are downloaded with
# HTTP range requests -- about 18 MB in total. All offsets are specific to
# the byte-identical dmg served by Apple's CDN, and everything extracted is
# verified against pinned sha256 checksums before it is installed.

URL_10126=https://updates.cdn-apple.com/2019/cert/041-90765-20191011-837e856d-b522-4865-b64c-641048ed77c4/macOSUpdCombo10.12.6.dmg

OSX_DRV=AppleCameraInterface
OSX_ASST=AppleCameraAssistant

# AppleCameraInterface spans two chunks: the last 249719 bytes of the first
# chunk's decompressed output plus the first 507353 bytes of the second's.
DRV_RANGE1=699186570-703316225
DRV_TAIL1=249719
DRV_RANGE2=703316242-707986973
DRV_HEAD2=507353
DRV_HASH_560=e959244db1e0561f6d5590c8e5000a36816c592e2820bafe89af0bea75556aca

# The firmware is a gzip stream inside the driver binary
FW_OFFSET_560=81920
FW_SIZE_560=602903
FW_HASH_560=240ef2e991f1d089d8228ce11d92b66bfa4b3d7289ec4fee228b64a713024330

# AppleCameraAssistant (the userspace plugin helper that carries the set
# files) lies within a single chunk.
ASST_RANGE=430282546-439105037
ASST_SKIP=7477241
ASST_SIZE=515632
ASST_HASH=af6a9de00472657e925f546753c818f9e33636030892b14ca96a1b4817ea58c7

# Set files inside AppleCameraAssistant: name, offset, size, sha256
SETFILES='
9112 217088 33060 4dd756fa8460d8dc3d78d0d76944b2f92275d1fe9c83181bbc8292c81c005f1a
1771 253952 19040 756c2bb7c5e55b395449e43a0be1cb7c40c37dfc6c2b5abfaffb8ae70ff0fc4b
1871 274432 19040 bf36fbde0668ab7e44368b584f9fa64b5945b01003d04c6e3c6f22c0be0fd5f3
1874 294912 19040 ffde89e7819ac16a9eb1c8f0bc6dba0e980b508b2022507679d901c190f7cef8
1222 315392 20076 04a6aa0d67c0353505a56187c573b27dfdef703dfb4b98329b1ee74f59e4ba7e
8221 335872 30240 2e041686cf2484345b08b18207266abe725f41f8869e04d427aa092071d9edde
1571 368640 18652 0f73f550b65121115fe0b999f016fb3be3d109057597863df9fe01fd4678c300
1575 389120 18652 31068eab65ba25a480fd4d0463e86f8e2807828a2e251a20b6f107499e0f7936
1674 409600 18044 32377ac603d764f33f1466b5e4a7e3e08780d7becc50ad5b00292e29e2dd0374
1675 430080 18044 b7a38aef2755721bb28c92d84a15654b17e9fb3b0a0f088a384a981fc8fe16d6
1671 450560 18044 0b90133936bf0bbcdde4b85df8d3fc18722b58d2f8a1afc2564c6c242b6c57fa
'

# Previous default: firmware 1.43.0 from OS X 10.11.5
URL_10115=https://updates.cdn-apple.com/2019/cert/041-88431-20191011-e7ee7d98-2878-4cd9-bc0a-d98b3a1e24b1/OSXUpd10.11.5.dmg
RANGE_10115=204909802-207733123
OSX_DRV_DIR=System/Library/Extensions/AppleCameraInterface.kext/Contents/MacOS
DRV_HASH_143=f56e68a880b65767335071531a1c75f3cfd4958adc6d871adf8dbf3b788e8ee1
FW_OFFSET_143=81920
FW_SIZE_143=603715
FW_HASH_143=e3e6034a67dfdaa27672dd547698bbc5b33f47f1fc7f5572a2fb68ea09d32d3d

fw_ver=5.60.0
setfiles=1

for arg in "$@"; do
	case "$arg" in
		--osx-10.11.5)
			fw_ver=1.43.0
			setfiles=0
			;;
		--no-setfiles)
			setfiles=0
			;;
		*)
			echo "Unknown option: $arg"
			echo "Usage: $0 [--osx-10.11.5] [--no-setfiles]"
			exit 1
			;;
	esac
done

if [[ "$EUID" != 0 ]]
	then echo "Please run as root"
	exit 1
fi

verify()
{
	local hash
	hash=$(sha256sum "$1" | awk '{ print $1 }')
	if [[ "$hash" != "$2" ]]; then
		echo "Incorrect $1 checksum. Aborting."
		exit 1
	fi
}

echo -e "FacetimeHD firmware download and installation script\n"

workdir=$(mktemp -d)
trap 'rm -rf "$workdir"' EXIT
cd "$workdir"

# Download one pbzx chunk (a complete xz stream) and decompress it to a file.
# The chunk is staged on disk and sliced from there so that no pipeline stage
# ever closes its input early; this keeps the script quiet and correct even
# where SIGPIPE is ignored (as in some package-install environments).
fetch_chunk()
{
	curl -s -L -r "$1" "$URL_10126" | xzcat -q 2> /dev/null > "$2"
}

# Cut $3 bytes starting at offset $2 out of file $1. Both head and tail
# consume their whole input, so no broken pipes.
slice()
{
	head -c "$(($2 + $3))" "$1" | tail -c "$3"
}

if [[ "$fw_ver" == "5.60.0" ]]; then
	echo -n "Downloading driver..."
	fetch_chunk "$DRV_RANGE1" chunk1
	fetch_chunk "$DRV_RANGE2" chunk2
	tail -c "$DRV_TAIL1" chunk1 > "$OSX_DRV"
	head -c "$DRV_HEAD2" chunk2 >> "$OSX_DRV"
	rm chunk1 chunk2
	echo "done"
	verify "$OSX_DRV" "$DRV_HASH_560"

	echo -n "Extracting firmware..."
	slice "$OSX_DRV" "$FW_OFFSET_560" "$FW_SIZE_560" | gzip -dc > firmware.bin
	rm "$OSX_DRV"
	echo "done"
	verify firmware.bin "$FW_HASH_560"

	if [[ "$setfiles" == 1 ]]; then
		echo -n "Downloading sensor calibration..."
		fetch_chunk "$ASST_RANGE" chunk1
		slice chunk1 "$ASST_SKIP" "$ASST_SIZE" > "$OSX_ASST"
		rm chunk1
		echo "done"
		verify "$OSX_ASST" "$ASST_HASH"

		echo -n "Extracting set files..."
		while read -r name offset size hash; do
			[[ -z "$name" ]] && continue
			slice "$OSX_ASST" "$offset" "$size" > "${name}_01XX.dat"
			verify "${name}_01XX.dat" "$hash"
		done <<< "$SETFILES"
		rm "$OSX_ASST"
		echo "done"
	fi
else
	echo -n "Downloading driver..."
	curl -s -L -r "$RANGE_10115" "$URL_10115" | xzcat -q 2> /dev/null \
		| cpio --format odc -i -d "./$OSX_DRV_DIR/$OSX_DRV" &> /dev/null
	if [[ ! -f "$OSX_DRV_DIR/$OSX_DRV" ]]; then
		echo "failed"
		echo "cpio could not unpack the driver. If this is BusyBox cpio, install GNU cpio. Aborting."
		exit 1
	fi
	mv "$OSX_DRV_DIR/$OSX_DRV" .
	rm -R ./System
	echo "done"
	verify "$OSX_DRV" "$DRV_HASH_143"

	echo -n "Extracting firmware..."
	slice "$OSX_DRV" "$FW_OFFSET_143" "$FW_SIZE_143" | gzip -dc > firmware.bin
	rm "$OSX_DRV"
	echo "done"
	verify firmware.bin "$FW_HASH_143"
fi

echo -n "Installing firmware..."
if [ -d "/usr/lib/firmware" ]; then
	FW_DIR=/usr/lib/firmware/facetimehd
else
	FW_DIR=/lib/firmware/facetimehd
fi

install -dm755 $FW_DIR
install -m644 firmware.bin $FW_DIR/firmware.bin
if [[ "$setfiles" == 1 ]]; then
	install -m644 ./*_01XX.dat $FW_DIR/
fi
echo "done"
