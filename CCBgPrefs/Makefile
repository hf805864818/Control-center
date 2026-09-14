export TARGET ?= iphone:clang:16.5:14.0
export ARCHS ?= arm64 arm64e

include $(THEOS)/makefiles/common.mk

BUNDLE_NAME = CustomCCBgPrefs

CC_PACKAGE_VERSION := $(shell cat ../VERSION 2>/dev/null | tr -d '[:space:]' || sed -n 's/^Version: //p' ../control | head -n 1 | tr -d '[:space:]')

CustomCCBgPrefs_FILES = CCBGRootListController.m \
                        CCBGProgressHUD.m \
                        CCBGMediaManager.m \
                        CCBGThumbnailButtonCell.m

CustomCCBgPrefs_CFLAGS = -fobjc-arc -DCC_PACKAGE_VERSION=@\"$(CC_PACKAGE_VERSION)\"
CustomCCBgPrefs_FRAMEWORKS = UIKit Foundation Photos AVFoundation
CustomCCBgPrefs_PRIVATE_FRAMEWORKS = Preferences
CustomCCBgPrefs_INSTALL_PATH = /Library/PreferenceBundles
CustomCCBgPrefs_RESOURCE_DIRS = Resources

include $(THEOS)/makefiles/bundle.mk

after-stage::
	ldid -S $(THEOS_STAGING_DIR)/Library/PreferenceBundles/CustomCCBgPrefs.bundle/CustomCCBgPrefs
	mkdir -p $(THEOS_STAGING_DIR)/Library/PreferenceLoader/Preferences
	cp Resources/entry.plist $(THEOS_STAGING_DIR)/Library/PreferenceLoader/Preferences/CustomCCBgPrefs.plist
