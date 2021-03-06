SHELL = /bin/bash

DEB_NAME:=facetimehd-firmware
DEB_VER:=0.1-1
DEB_BASE_DIR:=debian

DMG:=OSXUpd10.11.5.dmg
OSX_DRV:=AppleCameraInterface
OSX_DRV_DIR:=System/Library/Extensions/AppleCameraInterface.kext/Contents/MacOS

RANGE:=204909802-207733123

URL:=https://updates.cdn-apple.com/2019/cert/041-88431-20191011-e7ee7d98-2878-4cd9-bc0a-d98b3a1e24b1/$(DMG)
FILE:=$(OSX_DRV_DIR)/$(OSX_DRV)

ifneq ("$(wildcard /usr/lib/firmware)", "")
    FW_DIR_BASE:="/usr/lib/firmware"
else
    FW_DIR_BASE:="/lib/firmware"
endif

FW_DIR:="$(FW_DIR_BASE)/facetimehd"

all: $(OSX_DRV)
	@./extract-firmware.sh -x "$(OSX_DRV)"

deb: all
	@install -D -m 644 "firmware.bin" "$(DEB_BASE_DIR)/$(DEB_NAME)_$(DEB_VER)/lib/firmware/facetimehd/firmware.bin"
	@mkdir -p "$(DEB_BASE_DIR)/$(DEB_NAME)_$(DEB_VER)/DEBIAN"
	@(sed -e "s|^Package:.*|Package: $(DEB_NAME)|g" -e "s|^Version:.*|Version: $(DEB_VER)|g" "$(DEB_BASE_DIR)/control.template" > "$(DEB_BASE_DIR)/$(DEB_NAME)_$(DEB_VER)/DEBIAN/control")
	@fakeroot dpkg-deb --build "$(DEB_BASE_DIR)/$(DEB_NAME)_$(DEB_VER)"

$(OSX_DRV):
	@echo ""
	@echo "Checking dependencies for driver download..."
	@which curl xzcat cpio
	@echo ""
	@# Ty to wvengen, see: https://github.com/patjak/bcwc_pcie/issues/14#issuecomment-167446787
	@echo "Downloading the driver, please wait..."
	@(curl -k -L -r "$(RANGE)" "$(URL)" | xzcat -q | cpio --format odc -i -d "./$(FILE)") &> /dev/null || true
	@mv "$(FILE)" .
	@rmdir -p "$(OSX_DRV_DIR)"

install:
	@echo "Copying firmware into '$(DESTDIR)/$(FW_DIR)'"
	@install -dm755 "$(DESTDIR)/$(FW_DIR)"
	@install -m644 "firmware.bin" "$(DESTDIR)/$(FW_DIR)/firmware.bin"

.PHONY: clean
clean:
	rm -f AppleCamera{Interface,.sys}
	rm -f firmware.bin
	rm -rf "$(DEB_BASE_DIR)/$(DEB_NAME)_$(DEB_VER)"
	rm -f "$(DEB_BASE_DIR)"/*.deb
