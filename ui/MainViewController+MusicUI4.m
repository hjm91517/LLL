//
//  ui/MainViewController+MusicUI4.m
//  4.0 音乐页的额外入口：网易云登录键 + 免登录键。
//

#import <UIKit/UIKit.h>
#import <objc/runtime.h>
#import "MainViewController.h"
#import "MainViewController+Music4.h"
#import "MainViewController_Private.h"
#import "LLLMusicController.h"
#import "LLLCloudMusic.h"
#import "LLLCloudLogin.h"
#import "LLLGuestMusic.h"
#import "LLLMusicIsland.h"
#import "BaseComponents.h"
#import "AppTheme.h"

static void *kLLL4LoginBtn   = &kLLL4LoginBtn;
static void *kLLL4GuestBtn   = &kLLL4GuestBtn;

@implementation MainViewController (MusicUI4)

- (void)lll4_installLoginButton {
    if (objc_getAssociatedObject(self, kLLL4LoginBtn)) return;

    /* —— 登录键 —— */
    UIButton *btn = [UIButton buttonWithType:UIButtonTypeSystem];
    btn.translatesAutoresizingMaskIntoConstraints = NO;
    btn.backgroundColor = [UIColor colorWithRed:0.87 green:0.26 blue:0.26 alpha:1.0];
    btn.layer.cornerRadius = 15;
    btn.layer.cornerCurve = kCACornerCurveContinuous;
    btn.contentEdgeInsets = UIEdgeInsetsMake(0, 14, 0, 14);
    btn.titleLabel.font = [UIFont systemFontOfSize:12 weight:UIFontWeightSemibold];
    [btn setTitleColor:UIColor.whiteColor forState:UIControlStateNormal];
    [btn setTitle:@"网易云登录" forState:UIControlStateNormal];
    [btn addTarget:self action:@selector(lll4_tapCloudLogin) forControlEvents:UIControlEventTouchUpInside];

    /* —— 免登录键 —— */
    UIButton *guest = [UIButton buttonWithType:UIButtonTypeSystem];
    guest.translatesAutoresizingMaskIntoConstraints = NO;
    guest.backgroundColor = [UIColor colorWithWhite:1 alpha:0.12];
    guest.layer.cornerRadius = 15;
    guest.layer.cornerCurve = kCACornerCurveContinuous;
    guest.contentEdgeInsets = UIEdgeInsetsMake(0, 12, 0, 12);
    guest.titleLabel.font = [UIFont systemFontOfSize:12 weight:UIFontWeightMedium];
    [guest setTitleColor:[UIColor colorWithWhite:0.92 alpha:1] forState:UIControlStateNormal];
    [guest setTitle:@"免登录听" forState:UIControlStateNormal];
    [guest addTarget:self action:@selector(lll4_tapGuestMusic) forControlEvents:UIControlEventTouchUpInside];

    if (self.playerCard) {
        [self.playerCard addSubview:btn];
        [self.playerCard addSubview:guest];
        [NSLayoutConstraint activateConstraints:@[
            [btn.trailingAnchor constraintEqualToAnchor:self.playerCard.trailingAnchor constant:-16],
            [btn.topAnchor constraintEqualToAnchor:self.playerCard.topAnchor constant:16],
            [btn.heightAnchor constraintEqualToConstant:30],
            [btn.widthAnchor constraintGreaterThanOrEqualToConstant:96],

            [guest.trailingAnchor constraintEqualToAnchor:btn.leadingAnchor constant:-8],
            [guest.centerYAnchor constraintEqualToAnchor:btn.centerYAnchor],
            [guest.heightAnchor constraintEqualToConstant:30],
        ]];
        if (self.playerTitle) {
            [NSLayoutConstraint activateConstraints:@[
                [self.playerTitle.trailingAnchor constraintLessThanOrEqualToAnchor:guest.leadingAnchor constant:-8],
            ]];
        }
    }

    objc_setAssociatedObject(self, kLLL4LoginBtn, btn, OBJC_ASSOCIATION_RETAIN);
    objc_setAssociatedObject(self, kLLL4GuestBtn, guest, OBJC_ASSOCIATION_RETAIN);

    [NSNotificationCenter.defaultCenter addObserver:self
                                          selector:@selector(lll4_refreshLoginButton)
                                              name:LLLNowPlayingDidChange
                                            object:nil];
    [self lll4_refreshLoginButton];
}

- (void)lll4_tapCloudLogin {
    PlayHaptic(YES);
    [self openCloudMusic];
}

- (void)lll4_tapGuestMusic {
    PlayHaptic(YES);
    [self lll4_openGuestMusic];
}

- (void)lll4_refreshLoginButton {
    UIButton *btn = objc_getAssociatedObject(self, kLLL4LoginBtn);
    if (!btn) return;

    LLLCloudMusic *cm = [LLLCloudMusic shared];
    if (cm.loggedIn) {
        NSString *nick = cm.nickname.length ? cm.nickname : @"已登录";
        if (nick.length > 8) nick = [[nick substringToIndex:7] stringByAppendingString:@"…"];
        [btn setTitle:nick forState:UIControlStateNormal];
        btn.backgroundColor = [UIColor colorWithWhite:1 alpha:0.14];
        btn.layer.borderWidth = 0.6;
        btn.layer.borderColor = [UIColor colorWithRed:0.87 green:0.26 blue:0.26 alpha:0.9].CGColor;
    } else {
        [btn setTitle:@"网易云登录" forState:UIControlStateNormal];
        btn.backgroundColor = [UIColor colorWithRed:0.87 green:0.26 blue:0.26 alpha:1.0];
        btn.layer.borderWidth = 0;
    }
}

@end
