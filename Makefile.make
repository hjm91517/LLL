TARGET := iphone:clang:latest:14.0

FINALPACKAGE = 1

include $(THEOS)/makefiles/common.mk

TWEAK_NAME = MaterialPackManager

MaterialPackManager_FILES = core/BaseComponents.m \
                             core/ResourceManager.m \
                             core/EffectInjector.m \
                             core/CacheCleaner.m \
                             overlay/FloatMonitor.m \
                             ui/MainViewController.m \
                             ui/MainViewController+SettingsBackground.m \
                             ui/MainViewController+Features.m \
                             Entry.m

MaterialPackManager_FRAMEWORKS = UIKit Foundation AVFoundation PhotosUI
MaterialPackManager_CFLAGS = -fobjc-arc -O2 -fno-omit-frame-pointer -I. -I./core -I./overlay -I./ui
MaterialPackManager_LDFLAGS += -Wl,-U,___isPlatformVersionAtLeast

include $(THEOS_MAKE_PATH)/tweak.mk

