export TARGET ?= iphone:clang:16.5:14.0
export ARCHS ?= arm64 arm64e

include $(THEOS)/makefiles/common.mk

BUNDLE_NAME = CCToggle

CC_PACKAGE_VERSION := $(shell cat ../VERSION 2>/dev/null | tr -d '[:space:]' || sed -n 's/^Version: //p' ../control | head -n 1 | tr -d '[:space:]')

CCToggle_FILES = CCToggleModule.m
CCToggle_CFLAGS = -fobjc-arc -DCC_PACKAGE_VERSION=@\"$(CC_PACKAGE_VERSION)\"
CCToggle_FRAMEWORKS = UIKit Foundation CoreGraphics
CCToggle_INSTALL_PATH = /Library/ControlCenter/Bundles

include $(THEOS_MAKE_PATH)/bundle.mk

after-stage::
	# Sync version from VERSION file into Info.plist
	plutil -replace CFBundleShortVersionString -string "$(CC_PACKAGE_VERSION)" $(THEOS_STAGING_DIR)/Library/ControlCenter/Bundles/$(BUNDLE_NAME).bundle/Info.plist
	plutil -replace CFBundleVersion -string "$(CC_PACKAGE_VERSION)" $(THEOS_STAGING_DIR)/Library/ControlCenter/Bundles/$(BUNDLE_NAME).bundle/Info.plist

after-install::
	install.exec "killall -9 SpringBoard" || true
