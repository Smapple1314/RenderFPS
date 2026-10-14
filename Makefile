THEOS_PACKAGE_SCHEME ?= rootless
ifeq ($(THEOS_PACKAGE_SCHEME),roothide)
ARCHS = arm64e
else
ARCHS = arm64 arm64e
endif
TARGET = iphone:clang:latest:15.0
INSTALL_TARGET_PROCESSES = SpringBoard Preferences
include $(THEOS)/makefiles/common.mk
TWEAK_NAME = RenderFPS
RenderFPS_FILES = Overlay.xm Shared.m
RenderFPS_CFLAGS = -fobjc-arc
RenderFPS_FRAMEWORKS = UIKit Foundation QuartzCore Metal
include $(THEOS_MAKE_PATH)/tweak.mk
SUBPROJECTS += prefs
include $(THEOS_MAKE_PATH)/aggregate.mk
