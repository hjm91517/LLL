//
//  ui/MainViewController+Music4_Hook.m
//  把 lll4_installMusicPage 真正挂上：面板 viewDidLoad 跑完立刻安装。
//
//  此前一直没有调用点 → 登录按钮不存在、命令桥未安装、灵动岛按键无响应。
//

#import <UIKit/UIKit.h>
#import <objc/runtime.h>
#import "MainViewController.h"
#import "MainViewController+Music4.h"
#import "BaseComponents.h"

typedef void (*LLLViewDidLoadIMP)(id, SEL);
typedef void (*LLLViewWillAppearIMP)(id, SEL, BOOL);

static LLLViewDidLoadIMP     gOrigDidLoad      = NULL;
static LLLViewWillAppearIMP  gOrigWillAppear   = NULL;

static void LLLSwz_viewDidLoad(id self, SEL _cmd) {
    if (gOrigDidLoad) gOrigDidLoad(self, _cmd);
    @try {
        if ([self respondsToSelector:@selector(lll4_installMusicPage)]) {
            [(id)self lll4_installMusicPage];
        }
    } @catch (NSException *e) {
        lllLog(@"4.0 安装音乐页异常: %@", e);
    }
}

static void LLLSwz_viewWillAppear(id self, SEL _cmd, BOOL animated) {
    if (gOrigWillAppear) gOrigWillAppear(self, _cmd, animated);
    @try {
        /* 兜底：viewDidLoad 里 playerCard 可能还没建好 */
        if ([self respondsToSelector:@selector(lll4_installLoginButton)]) {
            [(id)self lll4_installLoginButton];
        }
    } @catch (NSException *e) { }
}

@implementation MainViewController (Music4Hook)

+ (void)load {
    static dispatch_once_t once;
    dispatch_once(&once, ^{
        @try {
            Class cls = [MainViewController class];

            SEL s1 = @selector(viewDidLoad);
            Method m1 = class_getInstanceMethod(cls, s1);
            if (m1) {
                gOrigDidLoad = (LLLViewDidLoadIMP)method_getImplementation(m1);
                method_setImplementation(m1, (IMP)LLLSwz_viewDidLoad);
            } else {
                lllLog(@"4.0 hook: viewDidLoad 不存在");
            }

            SEL s2 = @selector(viewWillAppear:);
            Method m2 = class_getInstanceMethod(cls, s2);
            if (m2) {
                gOrigWillAppear = (LLLViewWillAppearIMP)method_getImplementation(m2);
                method_setImplementation(m2, (IMP)LLLSwz_viewWillAppear);
            }
        } @catch (NSException *e) {
            lllLog(@"4.0 hook 异常: %@", e);
        }
    });
}

@end
