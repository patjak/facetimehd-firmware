#!/bin/bash

# firmware header bytestring [bytes 04-32]
fw_bytes_header="feffffeafeffffeafeffffeafeffffeafeffffeafeffffeafeffffea"
fw_bytes_footer="00000000ffffffff"

# Known driver hashes
#
# NOTE: use sha256 checksums as they are more robust that md5 against collisions
hash_drv_wnd_105='6ec37d48c0764ed059dd49f472456a4f70150297d6397b7cc7965034cf78627e'
hash_drv_wnd_138='7044344593bfc08ab9b41ab691213bca568c8d924d0e05136b537f66b3c46f31'
hash_drv_osx_140='387097b5133e980196ac51504a60ae1ad8bab736eb0070a55774925ca0194892'
hash_drv_osx_143_1='4667e6828f6bfc690a39cf9d561369a525f44394f48d0a98d750931b2f3f278b'
hash_drv_osx_143_2='d4650346c940dafdc50e5fcbeeeffe074ec359726773e79c0cfa601cec6b1f08'
hash_drv_osx_143_3='dfac86799c6cf0aceb59bb4e732be8f030e7943eb1146830c7136f62621c9853'
hash_drv_osx_143_5='f56e68a880b65767335071531a1c75f3cfd4958adc6d871adf8dbf3b788e8ee1'
hash_drv_osx_560='e959244db1e0561f6d5590c8e5000a36816c592e2820bafe89af0bea75556aca'

hash_fw_wnd_105='dabb8cf8e874451ebc85c51ef524bd83ddfa237c9ba2e191f8532b896594e50e'
hash_fw_wnd_138='ed75dc37b1a0e19949e9e046a629cb55deb6eec0f13ba8fd8dd49b5ccd5a800e'
hash_fw_osx_140='504fcf1565bf10d61b31a12511226ae51991fb55d480f82de202a2f7ee9c966e'
hash_fw_osx_143='e3e6034a67dfdaa27672dd547698bbc5b33f47f1fc7f5572a2fb68ea09d32d3d'
hash_fw_osx_145='e3e6034a67dfdaa27672dd547698bbc5b33f47f1fc7f5572a2fb68ea09d32d4d'
hash_fw_osx_560='240ef2e991f1d089d8228ce11d92b66bfa4b3d7289ec4fee228b64a713024330'

# Driver names
declare -A known_hashes=(
  ["$hash_drv_wnd_105"]='Windows Boot Camp 5.1.5722'
  ["$hash_drv_wnd_138"]='Windows Boot Camp Update Jul 29, 2015'
  ["$hash_drv_osx_140"]='OS X, El Capitan'
  ["$hash_drv_osx_143_1"]='OS X, El Capitan'
  ["$hash_drv_osx_143_2"]='OS X, El Capitan 10.11.2'
  ["$hash_drv_osx_143_3"]='OS X, El Capitan 10.11.3'
  ["$hash_drv_osx_143_5"]='OS X, El Capitan 10.11.5'
  ["$hash_drv_osx_560"]='macOS, Sierra 10.12.6'
)

# Offset in bytes of the firmware inside the driver
declare -A firmw_offsets=(
  ["$hash_drv_wnd_105"]=78208
  ["$hash_drv_wnd_138"]=85296
  ["$hash_drv_osx_140"]=81920
  ["$hash_drv_osx_143_1"]=81920
  ["$hash_drv_osx_143_2"]=81920
  ["$hash_drv_osx_143_3"]=81920
  ["$hash_drv_osx_143_5"]=81920
  ["$hash_drv_osx_560"]=81920
)

# Size in bytes of the firmware inside the driver 
declare -A firmw_sizes=(
  ["$hash_drv_wnd_105"]=1523716
  ["$hash_drv_wnd_138"]=1421316
  ["$hash_drv_osx_140"]=603715
  ["$hash_drv_osx_143_1"]=603715
  ["$hash_drv_osx_143_2"]=603715
  ["$hash_drv_osx_143_3"]=603715
  ["$hash_drv_osx_143_5"]=603715
  ["$hash_drv_osx_560"]=602903
)

# Compression method used to store the firmware inside the driver
declare -A compression=(
  ["$hash_drv_wnd_105"]='cat'
  ["$hash_drv_wnd_138"]='cat'
  ["$hash_drv_osx_140"]='gzip'
  ["$hash_drv_osx_143_1"]='gzip'
  ["$hash_drv_osx_143_2"]='gzip'
  ["$hash_drv_osx_143_3"]='gzip'
  ["$hash_drv_osx_143_5"]='gzip'
  ["$hash_drv_osx_560"]='gzip'
)

declare -A firmw_hashes=(
  ["$hash_fw_wnd_105"]='1.05'
  ["$hash_fw_wnd_138"]='1.38'
  ["$hash_fw_osx_140"]='1.40.0'
  ["$hash_fw_osx_143"]='1.43.0'
  ["$hash_fw_osx_145"]='1.45.0'
  ["$hash_fw_osx_560"]='5.60.0'
)

# Known hashes of binaries that carry the sensor calibration ("set") files.
# The assistant is the helper binary of the userspace camera plugin; the set
# files are not in the kext. The Boot Camp driver from Apple product 041-89042
# carries the same eleven files at different offsets; the older Boot Camp
# driver that facetimehd-data extracts from has only four of them.
hash_asst_osx_560='af6a9de00472657e925f546753c818f9e33636030892b14ca96a1b4817ea58c7'
hash_drv_wnd_bc6='0394f64872280d4833ecd1b4d262d07e017ad5b7ebb84130450cb63630323c36'

declare -A known_setfile_hashes=(
  ["$hash_asst_osx_560"]='macOS, Sierra 10.12.6 (AppleCameraAssistant)'
  ["$hash_drv_wnd_bc6"]='Windows Boot Camp 041-89042 (AppleCamera.sys)'
)

# Set file offsets per source binary, as "offset size". The tables are picked
# by hash at run time through a nameref, which shellcheck cannot follow.
setfile_names='9112 1771 1871 1874 1222 8221 1571 1575 1674 1675 1671'

# shellcheck disable=SC2034
declare -A setfile_offsets_560=(
  [9112]='217088 33060'
  [1771]='253952 19040'
  [1871]='274432 19040'
  [1874]='294912 19040'
  [1222]='315392 20076'
  [8221]='335872 30240'
  [1571]='368640 18652'
  [1575]='389120 18652'
  [1674]='409600 18044'
  [1675]='430080 18044'
  [1671]='450560 18044'
)

# shellcheck disable=SC2034
declare -A setfile_offsets_bc6=(
  [9112]='1854432 33060'
  [1771]='1781248 19040'
  [1871]='1743168 19040'
  [1874]='1762208 19040'
  [1222]='1887504 20076'
  [8221]='1907584 30240'
  [1571]='1937824 18652'
  [1575]='1956480 18652'
  [1674]='1800288 18044'
  [1675]='1818336 18044'
  [1671]='1836384 18044'
)

# One table for both sources: the eleven files are byte-identical wherever they
# come from, so extracting the same hashes out of two unrelated binaries is
# what validates both sets of offsets. 1675 is verified on a MacBook10,1 and
# 1571 on a MacBookPro14,1.
declare -A setfile_hashes=(
  [9112]='4dd756fa8460d8dc3d78d0d76944b2f92275d1fe9c83181bbc8292c81c005f1a'
  [1771]='756c2bb7c5e55b395449e43a0be1cb7c40c37dfc6c2b5abfaffb8ae70ff0fc4b'
  [1871]='bf36fbde0668ab7e44368b584f9fa64b5945b01003d04c6e3c6f22c0be0fd5f3'
  [1874]='ffde89e7819ac16a9eb1c8f0bc6dba0e980b508b2022507679d901c190f7cef8'
  [1222]='04a6aa0d67c0353505a56187c573b27dfdef703dfb4b98329b1ee74f59e4ba7e'
  [8221]='2e041686cf2484345b08b18207266abe725f41f8869e04d427aa092071d9edde'
  [1571]='0f73f550b65121115fe0b999f016fb3be3d109057597863df9fe01fd4678c300'
  [1575]='31068eab65ba25a480fd4d0463e86f8e2807828a2e251a20b6f107499e0f7936'
  [1674]='32377ac603d764f33f1466b5e4a7e3e08780d7becc50ad5b00292e29e2dd0374'
  [1675]='b7a38aef2755721bb28c92d84a15654b17e9fb3b0a0f088a384a981fc8fe16d6'
  [1671]='0b90133936bf0bbcdde4b85df8d3fc18722b58d2f8a1afc2564c6c242b6c57fa'
)

printHelp()
{
  cat <<HELP_DOC
Usage: extract-firmware [OPTIONS]

OPTION:

  -h  --help          Print this help message and exit.

  --dmg DMG_FILE      Decompress the dmg file DMG_FILE, and extract the
                      OS X camrea driver.

  -i  --ignore-hashes Ignore the firmware checksums and verify only the
                      binary header and footer of the extracted firmeare.

  -x DRV_FILE         Extract the firmware from the driver DRV_FILE

  -s SET_FILE_SRC     Extract the eleven sensor calibration set files
                      (NNNN_01XX.dat) from SET_FILE_SRC, which can be an
                      AppleCameraAssistant or the Boot Camp AppleCamera.sys
                      of Apple product 041-89042.

NOTES:

  Only two drivers are currently available:

   - AppleCameraInterface: this is the OS X native driver, it can be found
     in a OS X installation under the following system directory
     /System/Library/Extensions/AppleCameraInterface.kext/Contents/MacOS/

   - AppleCamera.sys: this comes within the bootcamp windows driver package.
     You can download it from http://support.apple.com/downloads/DL1831/".

  For most Macs only the version 1.43.0 of the firmware from OS X works.

  The 12-inch MacBook (MacBook8,1 / 9,1 / 10,1) is the exception: it needs
  version 5.60.0, from macOS Sierra 10.12.6. Firmware 1.43.0 predates those
  machines, so its sensor tables do not cover them and the ISP reports
  "sensor count: 0" with "Sensor is null after hNVStorage Validate".
  Extract 5.60.0 with -x from an AppleCameraInterface taken out of a
  10.12.6 install or update package.

  Besides the firmware, the camera needs a per-sensor calibration ("set")
  file. All eleven are embedded in AppleCameraAssistant, found in a macOS
  installation under
  /Library/CoreMediaIO/Plug-Ins/DAL/AppleCamera.plugin/Contents/Resources/
  and also in the AppleCamera.sys of the Boot Camp package for the 2017
  models, Apple product 041-89042, whose extraction the wiki documents.
  The older Boot Camp driver that facetimehd-data extracts from has only
  four of them. Extract from either with -s: the files are identical,
  only the offsets differ. The 12-inch MacBook needs 1675_01XX.dat.

  Both binaries can also be downloaded and installed directly from Apple's
  update servers by facetimehd-firmware-install.sh or 'make'.

HELP_DOC
}

msg()
{
  echo "==> $*"
}

msg2()
{
  echo " --> $*"
}

err()
{
  echo "Error: $*"
}

hasProgram()
{
  if ! which "$1" &> /dev/null; then
    err "'$1' needed but not found!"
    exit 1
  fi
}

checkDmgPrerequisites()
{
  hasProgram "7z"
  hasProgram "cpio"
  hasProgram "head"
  hasProgram "mkdir"
  hasProgram "pbzx"
  hasProgram "sha256sum"
  hasProgram "tail"
  hasProgram "xar"
}

checkPrerequisites()
{
  hasProgram "awk"
  hasProgram "dd"
  hasProgram "sha256sum"
  hasProgram "zcat"
}

getCheckSum()
{
  sha256sum "$1" | awk '{ print $1 }'
}

checkDriverHash()
{
  # computing the hash for the input file
  driver_hash="$(getCheckSum "$1")"

  # checking if it is among the known hashes
  for cur_hash in "${!known_hashes[@]}"; do
    if [[ "$driver_hash" == "$cur_hash" ]]; then
      echo "Found matching hash from ${known_hashes[$cur_hash]}"
      return
    fi
  done

  err "Mismatching driver hash for $1"
  err "The unknown hash is ${driver_hash}"
	err "No firmware extracted!"
  exit 1
}

checkFirmwareHash()
{
  # computing the hash for the input file
  fw_hash="$(getCheckSum "$1")"

  # checking if it is among the known hashes
  for cur_hash in "${!firmw_hashes[@]}"; do
    if [[ "$fw_hash" == "$cur_hash" ]]; then
      msg2 "Extracted firmware version ${firmw_hashes[$cur_hash]}"
      return 0
    fi
  done

  err "Mismatching firmware hash ${fw_hash}"
  return 1
}

checkFirmwareHexdump()
{
  if ! which hexdump &> /dev/null; then
    err "You need to install 'hexdump' in order to check a firmware with unknown hash!"
    return 1
  fi

  header=$(hexdump -v -e '"" /1 "%02x"' "$1" -s 4 -n 28)
  footer=$(hexdump -v -e '"" /1 "%02x"' "$1" | tail -c 16)

  if [[ "${header}" != "${fw_bytes_header}" ]]; then
    err "The extracted firmware does not seem good (wrong header)"
    return 1
  elif [[ "${footer}" != "${fw_bytes_footer}" ]]; then
    err "The extracted firmware does not seem good (wrong footer)"
    return 1
  else
    msg2 "You're lucky, the firmware looks good, " \
         "but it could also not work... use it at your own risk!"
  fi
}

extractFirmware()
{
  msg "Extracting firmware..."
  dd bs=1 skip="$3" count="$4" if="$1" of="$2.tmp" &> /dev/null

  msg2 "Decompressing the firmware using $5..."
  case "$5" in
    "gzip")
      zcat "$2.tmp" > "$2"
      ;;
    "cat")
      cat "$2.tmp" > "$2"
      ;;
  esac

  msg2 "Deleting temporary files..."
  rm "$2.tmp"
}

decompress_dmg()
{
  msg "Extracting the driver from $1..."

  msg2 "Creating temporary directories..."
  mkdir -p "${_main_dir}/temp"
  cd "${_main_dir}/temp" || exit 1

  msg2 "Decompressing the image..."
  7z e -y "${_main_dir}/$1" "5.hfs" > /dev/null

  msg2 "Extracting update package..."
  tail -c +189001729 "5.hfs" | head -c 661960661 > OSXUpd.xar
  rm -f "5.hfs"

  msg2 "Uncompressing XAR archive..."
  xar -x -f "OSXUpd.xar"
  rm -f "OSXUpd.xar"

  msg2 "Decoding Payload..."
  pbzx "OSXUpd"*.pkg"/Payload" > /dev/null
  rm "OSXUpd10.11.3.pkg/Payload"

  msg2 "Decompressing archives..."
  cd "OSXUpd10.11.3.pkg" || exit 1
  find . -name "Payload.part*.xz" -exec xz --decompress --verbose {} \;
  cat "Payload.part"* | cpio -id &> /dev/null
  cp "./System/Library/Extensions/AppleCameraInterface.kext/Contents/MacOS/AppleCameraInterface" \
     "${_main_dir}"
  msg2 "Cleaning up..."
  rm -rf "${_main_dir}/temp"
}

extract_from_osx()
{
 
  echo "" 
  checkDriverHash "$1"

  offset="${firmw_offsets[$driver_hash]}"
  size="${firmw_sizes[$driver_hash]}"
  comp_method="${compression[$driver_hash]}"

  extractFirmware "$1" "firmware.bin" "$offset" "$size" "$comp_method"

  if ! checkFirmwareHash "firmware.bin"; then
    if [[ -z "$skip_sums" ]]; then
	    err "No firmware extracted!"
      exit 1
    else
      msg2 "Ignoring hashes and check the firmware header..."
      checkFirmwareHexdump "firmware.bin"
    fi
  fi
}

checkSetfileSourceHash()
{
  # computing the hash for the input file
  setfile_hash="$(getCheckSum "$1")"

  # checking if it is among the known hashes
  for cur_hash in "${!known_setfile_hashes[@]}"; do
    if [[ "$setfile_hash" == "$cur_hash" ]]; then
      echo "Found matching hash from ${known_setfile_hashes[$cur_hash]}"
      return
    fi
  done

  err "Mismatching set file source hash for $1"
  err "The unknown hash is ${setfile_hash}"
  err "No set files extracted!"
  exit 1
}

extract_setfiles()
{
  echo ""
  checkSetfileSourceHash "$1"

  case "$setfile_hash" in
    "$hash_asst_osx_560")
      local -n offsets=setfile_offsets_560
      ;;
    "$hash_drv_wnd_bc6")
      local -n offsets=setfile_offsets_bc6
      ;;
    *)
      err "No offsets for ${known_setfile_hashes[$setfile_hash]}"
      err "No set files extracted!"
      exit 1
      ;;
  esac

  msg "Extracting sensor set files..."
  local name offset size
  for name in $setfile_names; do
    read -r offset size <<< "${offsets[$name]}"
    dd bs=1 skip="$offset" count="$size" if="$1" of="${name}_01XX.dat" &> /dev/null

    if [[ "$(getCheckSum "${name}_01XX.dat")" != "${setfile_hashes[$name]}" ]]; then
      err "Mismatching hash for ${name}_01XX.dat"
      local n
      for n in $setfile_names; do
        rm -f "${n}_01XX.dat"
      done
      err "No set files extracted!"
      exit 1
    fi
    msg2 "Extracted ${name}_01XX.dat"
  done
}

main()
{
  echo ""

  # Parsing arguments
  while [[ $# -gt 0 ]]; do
    case $1 in
      -h|--help)
        printHelp
        exit 1
        ;;
      --dmg)
        dmg_file="$2"
        shift
        ;;
      -x)
        drv_file="$2"
        shift
        ;;
      -s)
        setfile_src="$2"
        shift
        ;;
      -i|--ignore-hashes)
        skip_sums="1"
    esac
    shift
  done

  checkPrerequisites

  if [[ ! -z "$dmg_file" ]]; then
    checkDmgPrerequisites
    decompress_dmg "$dmg_file"
  fi

  cd "${_main_dir}" || exit 1

  if [[ ! -z "$drv_file" ]]; then
    extract_from_osx "$drv_file"
  fi

  if [[ ! -z "$setfile_src" ]]; then
    extract_setfiles "$setfile_src"
  fi

  echo ""
  exit 0
}

_main_dir="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"

main "$@"
