export TARGET ?= iphone:clang:16.5:14.0
export ARCHS ?= arm64 arm64e

CCENHANCER_DEBUG ?= 0
export CCENHANCER_DEBUG

# 从 VERSION 文件读取版本号, 回退到 control 文件
CC_PACKAGE_VERSION := $(shell cat VERSION 2>/dev/null | tr -d '[:space:]' || sed -n 's/^Version: //p' control | head -n 1 | tr -d '[:space:]')
export CC_PACKAGE_VERSION

INSTALL_TARGET_PROCESSES = SpringBoard

include $(THEOS)/makefiles/common.mk

TWEAK_NAME = CCEnhancer

CCEnhancer_FILES     = Tweak.x \
                       Shared/CCSharedSupport.m
CCEnhancer_CFLAGS    = -fobjc-arc -DCCENHANCER_DEBUG=$(CCENHANCER_DEBUG) -DCC_PACKAGE_VERSION=@\"$(CC_PACKAGE_VERSION)\"
CCEnhancer_FRAMEWORKS = UIKit QuartzCore AudioToolbox

include $(THEOS)/makefiles/tweak.mk

SUBPROJECTS += CCBg
SUBPROJECTS += CCBgPrefs
SUBPROJECTS += CCSliderPrefs
SUBPROJECTS += CCToggle

include $(THEOS_MAKE_PATH)/aggregate.mk
