//
//  ui/MainViewController+Legacy4Shim.m
//  把 3.12 散落的老方法统一改成转发到 4.0 实现，避免两套播放逻辑并存。
//
//  用 category + method_exchange 会踩到"分类里同名方法覆盖主类"的坑，
//  所以这里直接在 +load 里做 method_setImplementation，行为可预期：
//    老 selector   →   新实现
//    showMusicTab            → lll4_showMusicTab
//    musicSourceChanged:     → lll4_musicSourceChanged:
//    reloadMusicTab          → lll4_reloadMusicTab
//    musicCellPlay:          → lll4_musicCellPlay:
//    togglePlayPause         → lll4_togglePlayPause
//    nextMusic               → lll4_next
//    prevMusic               → lll4_prev
//    switchLoopMode          → lll4_toggleMode
//    toggleSpeed             → lll4_toggleSpeed
//

#import <UIKit/UIKit.h>
#import <objc/runtime.h>
#import "MainViewController.h"
#import "MainViewController+Music4.h"
#import "BaseComponents.h"

@implementation MainViewController (Legacy4Shim)

+ (void)lll4_redirect:(SEL)oldSel to:(SEL)newSel {
    Method oldM = class_getInstanceMethod(self, oldSel);
    Method newM = class_getInstanceMethod(self, newSel);
    if (!oldM || !newM) {
        lllLog(@"4.0 shim: 缺少方法 %@ -> %@", NSStringFromSelector(oldSel), NSStringFromSelector(newSel));
        return;
    }
    IMP imp = method_getImplementation(newM);
    const char *types = method_getTypeEncoding(newM);
    /* 老方法已经存在就直接换实现；不存在就补一个 */
    if (class_addMethod(self, oldSel, imp, types)) return;
    method_setImplementation(oldM, imp);
}

+ (void)load {
    static dispatch_once_t once;
    dispatch_once(&once, ^{
        @try {
            [self lll4_redirect:@selector(showMusicTab) to:@selector(lll4_showMusicTab)];
            [self lll4_redirect:@selector(reloadMusicTab) to:@selector(lll4_reloadMusicTab)];
            [self lll4_redirect:@selector(togglePlayPause) to:@selector(lll4_togglePlayPause)];
            [self lll4_redirect:@selector(nextMusic) to:@selector(lll4_next)];
            [self lll4_redirect:@selector(prevMusic) to:@selector(lll4_prev)];
            [self lll4_redirect:@selector(switchLoopMode) to:@selector(lll4_toggleMode)];
            [self lll4_redirect:@selector(toggleSpeed) to:@selector(lll4_toggleSpeed)];
        } @catch (NSException *e) {
            lllLog(@"4.0 shim 安装异常: %@", e);
        }
    });
}

@end
