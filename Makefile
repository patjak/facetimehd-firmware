SHELL = /bin/bash

DEB_NAME:=facetimehd-firmware
DEB_VER:=0.1-1
DEB_BASE_DIR:=debian

# Firmware selection: 5.60.0 (from macOS 10.12.6, the default) also supports
# the 12-inch MacBook and comes with all eleven sensor set files; build with
# FW_VER=1.43.0 for the previous firmware from OS X 10.11.5 (firmware only).
FW_VER?=5.60.0

OSX_DRV:=AppleCameraInterface
OSX_ASST:=AppleCameraAssistant

ifeq ($(FW_VER),5.60.0)

DMG:=macOSUpdCombo10.12.6.dmg
URL:=https://updates.cdn-apple.com/2019/cert/041-90765-20191011-837e856d-b522-4865-b64c-641048ed77c4/$(DMG)

# The update payload is pbzx. Each range below covers one complete xz stream
# (chunk), so xzcat can decode it directly; the wanted bytes are then cut out
# of the 16MiB decompressed chunk. The driver spans two adjacent chunks.
DRV_RANGE1:=699186570-703316225
DRV_TAIL1:=249719
DRV_RANGE2:=703316242-707986973
DRV_HEAD2:=507353
ASST_RANGE:=430282546-439105037
ASST_SKIP:=7477241
ASST_SIZE:=515632

else

DMG:=OSXUpd10.11.5.dmg
OSX_DRV_DIR:=System/Library/Extensions/AppleCameraInterface.kext/Contents/MacOS

RANGE:=204909802-207733123

URL:=https://updates.cdn-apple.com/2019/cert/041-88431-20191011-e7ee7d98-2878-4cd9-bc0a-d98b3a1e24b1/$(DMG)
FILE:=$(OSX_DRV_DIR)/$(OSX_DRV)

endif

ifneq ("$(wildcard /usr/lib/firmware)", "")
    FW_DIR_BASE:="/usr/lib/firmware"
else
    FW_DIR_BASE:="/lib/firmware"
endif

FW_DIR:="$(FW_DIR_BASE)/facetimehd"

ifeq ($(FW_VER),5.60.0)

all: $(OSX_DRV) $(OSX_ASST)
	@./extract-firmware.sh -x "$(OSX_DRV)" -s "$(OSX_ASST)"

$(OSX_DRV):
	@echo ""
	@echo "Checking dependencies for driver download..."
	@which curl xzcat
	@echo ""
	@# Chunks are staged on disk and sliced from there so no pipeline stage
	@# closes its input early (avoids broken-pipe noise where SIGPIPE is ignored)
	@echo "Downloading the driver, please wait..."
	@curl -k -s -L -r "$(DRV_RANGE1)" "$(URL)" | xzcat -q > "$@.chunk1"
	@curl -k -s -L -r "$(DRV_RANGE2)" "$(URL)" | xzcat -q > "$@.chunk2"
	@tail -c "$(DRV_TAIL1)" "$@.chunk1" > "$@"
	@head -c "$(DRV_HEAD2)" "$@.chunk2" >> "$@"
	@rm -f "$@.chunk1" "$@.chunk2"

$(OSX_ASST):
	@echo "Downloading the camera assistant, please wait..."
	@curl -k -s -L -r "$(ASST_RANGE)" "$(URL)" | xzcat -q > "$@.chunk"
	@head -c $$(($(ASST_SKIP)+$(ASST_SIZE))) "$@.chunk" | tail -c "$(ASST_SIZE)" > "$@"
	@rm -f "$@.chunk"

else

all: $(OSX_DRV)
	@./extract-firmware.sh -x "$(OSX_DRV)"

$(OSX_DRV):
	@echo ""
	@echo "Checking dependencies for driver download..."
	@which curl xzcat cpio
	@echo ""
	@# Ty to wvengen, see: https://github.com/patjak/bcwc_pcie/issues/14#issuecomment-167446787
	@echo "Downloading the driver, please wait..."
	@(curl -k -L -r "$(RANGE)" "$(URL)" | xzcat -q | cpio --format odc -i -d "./$(FILE)") &> /dev/null || true
	@test -f "$(FILE)" || { echo "cpio could not unpack the driver. If this is BusyBox cpio, install GNU cpio."; exit 1; }
	@mv "$(FILE)" .
	@rmdir -p "$(OSX_DRV_DIR)"

endif

deb: all
	@install -D -m 644 "firmware.bin" "$(DEB_BASE_DIR)/$(DEB_NAME)_$(DEB_VER)/lib/firmware/facetimehd/firmware.bin"
	@if ls *_01XX.dat &> /dev/null; then \
		install -m 644 *_01XX.dat "$(DEB_BASE_DIR)/$(DEB_NAME)_$(DEB_VER)/lib/firmware/facetimehd/"; \
	fi
	@mkdir -p "$(DEB_BASE_DIR)/$(DEB_NAME)_$(DEB_VER)/DEBIAN"
	@(sed -e "s|^Package:.*|Package: $(DEB_NAME)|g" -e "s|^Version:.*|Version: $(DEB_VER)|g" "$(DEB_BASE_DIR)/control.template" > "$(DEB_BASE_DIR)/$(DEB_NAME)_$(DEB_VER)/DEBIAN/control")
	@fakeroot dpkg-deb --build "$(DEB_BASE_DIR)/$(DEB_NAME)_$(DEB_VER)"

install:
	@echo "Copying firmware into '$(DESTDIR)/$(FW_DIR)'"
	@install -dm755 "$(DESTDIR)/$(FW_DIR)"
	@install -m644 "firmware.bin" "$(DESTDIR)/$(FW_DIR)/firmware.bin"
	@if ls *_01XX.dat &> /dev/null; then \
		echo "Copying sensor set files into '$(DESTDIR)/$(FW_DIR)'"; \
		install -m644 *_01XX.dat "$(DESTDIR)/$(FW_DIR)/"; \
	fi

.PHONY: clean
clean:
	rm -f AppleCamera{Interface,Assistant,.sys}
	rm -f firmware.bin
	rm -f *_01XX.dat
	rm -rf "$(DEB_BASE_DIR)/$(DEB_NAME)_$(DEB_VER)"
	rm -f "$(DEB_BASE_DIR)"/*.deb
