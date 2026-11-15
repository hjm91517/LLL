//
//  ui/MainViewController+Legacy4Shim.m
//  老 selector → 4.0 实现。缺一个就会出现「界面与内核脱节」。
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
    if (!newM) {
        lllLog(@"4.0 shim: 新方法缺失 %@", NSStringFromSelector(newSel));
        return;
    }
    IMP imp = method_getImplementation(newM);
    const char *types = method_getTypeEncoding(newM);
    if (class_addMethod(self, oldSel, imp, types)) return;
    if (oldM) method_setImplementation(oldM, imp);
}

+ (void)load {
    static dispatch_once_t once;
    dispatch_once(&once, ^{
        @try {
            /* 页面切换 */
            [self lll4_redirect:@selector(showMusicTab) to:@selector(lll4_showMusicTab)];
            [self lll4_redirect:@selector(reloadMusicTab) to:@selector(lll4_reloadMusicTab)];
            [self lll4_redirect:@selector(musicSourceChanged:)
                             to:@selector(lll4_musicSourceChanged:)];

            /* 选歌 / 播放 */
            [self lll4_redirect:@selector(playMusicAtIndex:)
                             to:@selector(lll4_playMusicAtIndex:)];
            [self lll4_redirect:@selector(musicCellPlay:)
                             to:@selector(lll4_musicCellPlay:)];
            [self lll4_redirect:@selector(stopMusic) to:@selector(lll4_stopMusic)];

            /* 传输控制 */
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
