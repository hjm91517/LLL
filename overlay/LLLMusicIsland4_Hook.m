//
//  overlay/LLLMusicIsland4_Hook.m
//  在岛 buildIfNeeded 完成后挂上 4.0 的两颗新键。
//
//  为什么不在主实现里调：
//    主实现是 3.12 的文件，一行不动更省心。这里用 +load 给 LLLMusicIsland
//    的 buildIfNeeded 包一层：原逻辑跑完 → 找到 pill → 挂按钮。
//

#import <UIKit/UIKit.h>
#import <objc/runtime.h>
#import "LLLMusicIsland.h"
#import "LLLMusicIsland4.h"
#import "BaseComponents.h"

typedef id (*LLLBuildIMP)(id, SEL);

static LLLBuildIMP gOrigBuild = NULL;
static BOOL gHooked = NO;

static id LLLBuildSwizzled(id self, SEL _cmd) {
    id result = gOrigBuild ? gOrigBuild(self, _cmd) : nil;

    /* 找到胶囊 pill：它是 islandWindow.rootViewController.view 的第一个子视图 */
    @try {
        Class cls = [LLLMusicIsland class];
        SEL winSel = NSSelectorFromString(@"islandWindow");
        UIView *pill = nil;

        if ([cls respondsToSelector:winSel]) {
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Warc-performSelector-leaks"
            UIWindow *win = [cls performSelector:winSel];
#pragma clang diagnostic pop
            UIView *host = win.rootViewController.view;
            for (UIView *v in host.subviews) {
                if (v.tag == 777001) { pill = v; break; }
            }
        }

        if (pill) {
            [LLLMusicIsland lll4_attachButtonsToPill:pill];
        }
    } @catch (__unused NSException *e) { }

    return result;
}

@implementation LLLMusicIsland (Hook4)

+ (void)load {
    static dispatch_once_t once;
    dispatch_once(&once, ^{
        if (gHooked) return;
        @try {
            SEL sel = NSSelectorFromString(@"buildIfNeeded");
            Method m = class_getClassMethod([LLLMusicIsland class], sel);
            if (m) {
                gOrigBuild = (LLLBuildIMP)method_getImplementation(m);
                method_setImplementation(m, (IMP)LLLBuildSwizzled);
                gHooked = YES;
            } else {
                lllLog(@"4.0 hook: 找不到 buildIfNeeded");
            }
        } @catch (NSException *e) {
            lllLog(@"4.0 hook 异常: %@", e);
        }
    });
}

@end
