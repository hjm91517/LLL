//
//  ui/LLLGuestPanel.m
//  免登录入口：搜索 + 飙升榜。不需要账号即可打开、搜索、点播免费曲目。
//

#import <UIKit/UIKit.h>
#import "MainViewController.h"
#import "MainViewController+Music4.h"        /* lll4_refreshCard */
#import "MainViewController+MusicUI4.h"      /* 免登录面板自身的方法声明 */
#import "MainViewController+CloudLists4.h"   /* showLikedSongs */
#import "LLLCloudLogin.h"                    /* presentLoginChooser */
#import "LLLGuestMusic.h"
#import "LLLMusicController.h"
#import "LLLCloudMusic.h"
#import "LLLUiKit.h"
#import "BaseComponents.h"
#import "AppTheme.h"

static UITextField *gGuestField = nil;
static void (^gGuestClose)(void) = nil;

@implementation MainViewController (GuestPanel4)

/// 第一层：免登录菜单
- (void)lll4_openGuestMusic {
    __weak typeof(self) w = self;
    LLLShowSheet(@"网易云 · 免登录", [LLLGuestMusic capabilityNote],
                 @[ @"搜索歌曲", @"云音乐飙升榜", @"我喜欢的音乐（需登录）", @"登录账号" ], NO,
                 ^(NSInteger idx) {
        __strong typeof(w) s = w;
        if (!s) return;
        if (idx == 0) [s lll4_guestSearch];
        else if (idx == 1) [s lll4_guestTopList];
        else if (idx == 2) [s showLikedSongs];
        else [s presentLoginChooser];
    });
}

- (void)lll4_guestSearch {
    __weak typeof(self) w = self;
    LLLShowCustomCard(320, 200, ^(UIView *card, void (^close)(void)) {
        __strong typeof(w) s = w;
        if (!s) return;

        gGuestClose = [close copy];
        CGFloat cw = card.bounds.size.width > 1 ? card.bounds.size.width : 320;
        card.frame = CGRectMake(0, 0, cw, 156);

        UILabel *t = [[UILabel alloc] initWithFrame:CGRectMake(16, 16, cw - 32, 22)];
        t.text = @"搜索（免登录）";
        t.font = [UIFont systemFontOfSize:15 weight:UIFontWeightSemibold];
        t.textColor = UIColor.whiteColor;
        t.textAlignment = NSTextAlignmentCenter;
        [card addSubview:t];

        UITextField *f = [[UITextField alloc] initWithFrame:CGRectMake(16, 50, cw - 32, 38)];
        f.backgroundColor = [UIColor colorWithWhite:1 alpha:0.10];
        f.layer.cornerRadius = 10;
        f.textColor = UIColor.whiteColor;
        f.tintColor = LLLAccentColor();
        f.placeholder = @"歌名 / 歌手";
        f.font = [UIFont systemFontOfSize:14];
        f.autocorrectionType = UITextAutocorrectionTypeNo;
        f.autocapitalizationType = UITextAutocapitalizationTypeNone;
        f.leftView = [[UIView alloc] initWithFrame:CGRectMake(0, 0, 12, 38)];
        f.leftViewMode = UITextFieldViewModeAlways;
        [card addSubview:f];
        gGuestField = f;

        UIButton *go = [UIButton buttonWithType:UIButtonTypeSystem];
        go.frame = CGRectMake(16, 98, cw - 32, 42);
        go.backgroundColor = LLLAccentColor();
        go.layer.cornerRadius = 12;
        [go setTitle:@"搜索" forState:UIControlStateNormal];
        [go setTitleColor:UIColor.whiteColor forState:UIControlStateNormal];
        go.titleLabel.font = [UIFont systemFontOfSize:15 weight:UIFontWeightSemibold];
        [go addTarget:s action:@selector(lll4_doGuestSearch)
     forControlEvents:UIControlEventTouchUpInside];
        [card addSubview:go];
    });
}

- (void)lll4_doGuestSearch {
    NSString *kw = [gGuestField.text stringByTrimmingCharactersInSet:
                    [NSCharacterSet whitespaceAndNewlineCharacterSet]];
    if (!kw.length) { ShowToast(@"先输入关键词", 1.5, YES, YES); return; }

    if (gGuestClose) { gGuestClose(); gGuestClose = nil; }
    gGuestField = nil;

    ShowToast(@"搜索中…", 1.2, YES, NO);
    __weak typeof(self) w = self;
    [[LLLGuestMusic shared] search:kw done:^(NSArray<NSDictionary *> *songs, NSString *err) {
        dispatch_async(dispatch_get_main_queue(), ^{
            __strong typeof(w) s = w;
            if (!s) return;
            if (!songs.count) { ShowToast(err.length ? err : @"没搜到", 2, YES, YES); return; }
            [s lll4_presentGuestList:songs
                               title:[NSString stringWithFormat:@"“%@” 的结果", kw]];
        });
    }];
}

- (void)lll4_guestTopList {
    ShowToast(@"正在拉飙升榜…", 1.2, YES, NO);
    __weak typeof(self) w = self;
    [[LLLGuestMusic shared] loadTopList:^(NSArray<NSDictionary *> *songs, NSString *err) {
        dispatch_async(dispatch_get_main_queue(), ^{
            __strong typeof(w) s = w;
            if (!s) return;
            if (!songs.count) { ShowToast(err.length ? err : @"榜单拿不到", 2, YES, YES); return; }
            [s lll4_presentGuestList:songs title:@"云音乐飙升榜"];
        });
    }];
}

- (void)lll4_presentGuestList:(NSArray<NSDictionary *> *)songs title:(NSString *)title {
    if (!songs.count) return;

    NSUInteger limit = MIN(songs.count, (NSUInteger)200);
    NSMutableArray<NSString *> *titles = [NSMutableArray arrayWithCapacity:limit];
    for (NSUInteger i = 0; i < limit; i++) {
        NSDictionary *sg = songs[i];
        NSString *name = sg[@"name"] ?: @"未知";
        NSString *artist = sg[@"artist"] ?: @"";
        [titles addObject:artist.length
                            ? [NSString stringWithFormat:@"%@ - %@", name, artist]
                            : name];
    }

    [[LLLMusicController shared] setCloudQueueDirectly:songs];

    __weak typeof(self) w = self;
    LLLShowList(title, [LLLGuestMusic capabilityNote], titles, ^(NSInteger idx) {
        __strong typeof(w) s = w;
        if (!s) return;
        if (idx < 0 || idx >= (NSInteger)limit) return;
        [[LLLMusicController shared] playCloudRowDirectly:idx];
        [s lll4_refreshCard];
    });
}

@end
