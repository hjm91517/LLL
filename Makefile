#
# bbhj online - 资源注入器
# Theos 工程定义
#
# 注意：文件名必须是 Makefile（不是 Makefile.make），否则 make 根本读不到。
#

ifeq ($(THEOS),)
$(error THEOS 环境变量未设置，先装 Theos 或跑 GitHub Actions)
endif

TARGET := iphone:clang:latest:14.0
FINALPACKAGE = 1
DEBUG = 0

ARCHS ?= arm64 arm64e

include $(THEOS)/makefiles/common.mk

TWEAK_NAME = bbhj_online

bbhj_online_FILES = \
    core/BaseComponents.m \
    core/ResourceManager.m \
    core/EffectInjector.m \
    core/CacheCleaner.m \
    overlay/FloatMonitor.m \
    overlay/LLLNowPlaying.m \
    overlay/LLLMusicIsland.m \
    ui/MainViewController.m \
    ui/MainViewController+SettingsBackground.m \
    ui/MainViewController+Features.m \
    ui/LLLUiKit.m \
    ui/LLLLaunchCard.m \
    core/LLLStealth.m \
    core/LLLZip.m \
    core/FoliaPayload.m \
    overlay/FoliaPlayer.m \
    Entry.m

# ImageIO 必须显式链接：BaseComponents.m 用 CGImageSourceCreateWithURL 做缩略图，
# 不写 -framework ImageIO 在真机上会走不到，链接期也容易莫名 undefined。
bbhj_online_FRAMEWORKS = UIKit Foundation AVFoundation PhotosUI ImageIO CoreImage CoreGraphics Security WebKit

bbhj_online_CFLAGS = \
    -fobjc-arc \
    -fmodules \
    -O2 \
    -fno-omit-frame-pointer \
    -Wno-deprecated-declarations \
    -Wno-unused-variable \
    -Wno-unused-function \
    -Wno-nullability-completeness \
    -I. -I./core -I./overlay -I./ui

# ___isPlatformVersionAtLeast 是 @available 展开出来的符号，老设备上要允许未定义
bbhj_online_LDFLAGS = -Wl,-U,___isPlatformVersionAtLeast -lz

include $(THEOS_MAKE_PATH)/tweak.mk
