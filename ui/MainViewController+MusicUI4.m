//
//  ui/MainViewController+MusicUI4.m
//  4.0 音乐页 UI 元素：登录按钮 + 分段控件旁边那行
//
//  需求原话：「在音乐播放器那个网易云那里增加按键网易云登录」
//  位置：播放卡片标题右侧（与 3.12 去掉的那个云图标同位，但这是明确的按钮＋文字）
//

#import <UIKit/UIKit.h>
#import <objc/runtime.h>
#import "MainViewController.h"
#import "MainViewController+Music4.h"
#import "MainViewController_Private.h"
#import "LLLMusicController.h"
#import "LLLCloudMusic.h"
#import "LLLCloudLogin.h"
#import "LLLMusicIsland.h"
#import "BaseComponents.h"
#import "AppTheme.h"

static void *kLLL4LoginBtn = &kLLL4LoginBtn;

@implementation MainViewController (MusicUI4)

- (void)lll4_installLoginButton {
    if (objc_getAssociatedObject(self, kLLL4LoginBtn)) return;

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

    /* 挂在播放卡片上：卡片本身就是音乐页的主视觉，放这里最显眼 */
    if (self.playerCard) {
        [self.playerCard addSubview:btn];
        [NSLayoutConstraint activateConstraints:@[
            [btn.trailingAnchor constraintEqualToAnchor:self.playerCard.trailingAnchor constant:-16],
            [btn.topAnchor constraintEqualToAnchor:self.playerCard.topAnchor constant:16],
            [btn.heightAnchor constraintEqualToConstant:30],
            [btn.widthAnchor constraintGreaterThanOrEqualToConstant:92],
        ]];
        /* 标题别跟按钮打架 */
        if (self.playerTitle) {
            [NSLayoutConstraint activateConstraints:@[
                [self.playerTitle.trailingAnchor constraintLessThanOrEqualToAnchor:btn.leadingAnchor constant:-8],
            ]];
        }
    }

    objc_setAssociatedObject(self, kLLL4LoginBtn, btn, OBJC_ASSOCIATION_RETAIN);

    [NSNotificationCenter.defaultCenter
     addObserver:self
        selector:@selector(lll4_refreshLoginButton)
            name:LLLNowPlayingDidChange
          object:nil];
    [self lll4_refreshLoginButton];
}

- (void)lll4_tapCloudLogin {
    PlayHaptic(YES);
    [self openCloudMusic];
}

- (void)lll4_refreshLoginButton {
    UIButton *btn = objc_getAssociatedObject(self, kLLL4LoginBtn);
    if (!btn) return;

    LLLCloudMusic *cm = [LLLCloudMusic shared];
    if (cm.loggedIn) {
        NSString *nick = cm.nickname.length ? cm.nickname : @"已登录";
        if (nick.length > 8) nick = [[nick substringToIndex:7] stringByAppendingString:@"…"];
        [btn setTitle:[NSString stringWithFormat:@"%@", nick] forState:UIControlStateNormal];
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
