export TARGET ?= iphone:clang:16.5:14.0
export ARCHS ?= arm64 arm64e

include $(THEOS)/makefiles/common.mk

BUNDLE_NAME = CCSliderPrefs

CC_PACKAGE_VERSION := $(shell cat ../VERSION 2>/dev/null | tr -d '[:space:]' || sed -n 's/^Version: //p' ../control | head -n 1 | tr -d '[:space:]')

CCSliderPrefs_FILES = CCSliderRootListController.m
CCSliderPrefs_CFLAGS = -fobjc-arc -DCC_PACKAGE_VERSION=@\"$(CC_PACKAGE_VERSION)\" -Wno-unused-function -Wno-unused-variable
CCSliderPrefs_FRAMEWORKS = UIKit Foundation
CCSliderPrefs_PRIVATE_FRAMEWORKS = Preferences
CCSliderPrefs_INSTALL_PATH = /Library/PreferenceBundles
CCSliderPrefs_RESOURCE_DIRS = Resources

include $(THEOS)/makefiles/bundle.mk

after-stage::
	ldid -S $(THEOS_STAGING_DIR)/Library/PreferenceBundles/CCSliderPrefs.bundle/CCSliderPrefs
	mkdir -p $(THEOS_STAGING_DIR)/Library/PreferenceLoader/Preferences
	cp Resources/entry.plist $(THEOS_STAGING_DIR)/Library/PreferenceLoader/Preferences/CCSliderPrefs.plist
