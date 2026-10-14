THEOS_PACKAGE_SCHEME ?= rootless

ifeq ($(THEOS_PACKAGE_SCHEME),roothide)
ARCHS = arm64e
else
ARCHS = arm64 arm64e
endif

TARGET = iphone:clang:16.5:15.0

include $(THEOS)/makefiles/common.mk

BUNDLE_NAME = RenderFPSPrefs
RenderFPSPrefs_FILES = RFSettings.m ../Shared.m
RenderFPSPrefs_INSTALL_PATH = /Library/PreferenceBundles
RenderFPSPrefs_FRAMEWORKS = UIKit Foundation
RenderFPSPrefs_PRIVATE_FRAMEWORKS = Preferences
RenderFPSPrefs_CFLAGS = -fobjc-arc

include $(THEOS_MAKE_PATH)/bundle.mk
