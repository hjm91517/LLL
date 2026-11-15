//
//  ui/LLLGuestPanel.m
//  免登录入口：搜索 / 飙升榜 / 解锁音源（本地 / 外部）。
//

#import <UIKit/UIKit.h>
#import "MainViewController.h"
#import "MainViewController+GuestPanel4.h"
#import "MainViewController+Music4.h"
#import "MainViewController+CloudLists4.h"
#import "LLLCloudLogin.h"
#import "LLLGuestMusic.h"
#import "LLLUnblockSource.h"
#import "LLLUnblockServer.h"
#import "LLLMusicController.h"
#import "LLLCloudMusic.h"
#import "LLLUiKit.h"
#import "BaseComponents.h"
#import "AppTheme.h"

static UITextField *gGuestField = nil;
static UITextField *gUnblockField = nil;
static void (^gGuestClose)(void) = nil;

@implementation MainViewController (GuestPanel4)

- (void)lll4_openGuestMusic {
    __weak typeof(self) w = self;
    BOOL ext = [[LLLUnblockSource shared] isConfigured];
    BOOL local = [[LLLUnblockServer shared] localBaseURL].length > 0;
    NSString *unblockTitle = ext ? @"解锁音源（外部服务）"
                           : (local ? @"解锁音源（本地已就绪）" : @"解锁音源");

    LLLShowSheet(@"网易云 · 免登录", [LLLGuestMusic capabilityNote],
                 @[ @"搜索歌曲", @"云音乐飙升榜", unblockTitle,
                    @"我喜欢的音乐（需登录）", @"登录账号" ], NO,
                 ^(NSInteger idx) {
        __strong typeof(w) s = w;
        if (!s) return;
        if (idx == 0) [s lll4_guestSearch];
        else if (idx == 1) [s lll4_guestTopList];
        else if (idx == 2) [s lll4_setupUnblockSource];
        else if (idx == 3) [s showLikedSongs];
        else [s presentLoginChooser];
    });
}

#pragma mark - 搜索

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

#pragma mark - 解锁音源

- (void)lll4_setupUnblockSource {
    __weak typeof(self) w = self;

    /* 先尝试拉起本地服务 */
    LLLUnblockServer *srv = [LLLUnblockServer shared];
    if (!srv.localBaseURL.length) [srv start];
    NSString *localURL = [srv localBaseURL];
    NSString *ext = [[LLLUnblockSource shared] baseURL];

    NSString *status;
    if (localURL.length) status = [NSString stringWithFormat:@"本地服务运行中：%@", localURL];
    else                 status = @"本地服务未启动";

    LLLShowCustomCard(320, 300, ^(UIView *card, void (^close)(void)) {
        __strong typeof(w) s = w;
        if (!s) return;

        gGuestClose = [close copy];
        CGFloat cw = card.bounds.size.width > 1 ? card.bounds.size.width : 320;
        card.frame = CGRectMake(0, 0, cw, 256);

        UILabel *t = [[UILabel alloc] initWithFrame:CGRectMake(16, 12, cw - 32, 20)];
        t.text = @"解锁音源";
        t.font = [UIFont systemFontOfSize:15 weight:UIFontWeightSemibold];
        t.textColor = UIColor.whiteColor;
        t.textAlignment = NSTextAlignmentCenter;
        [card addSubview:t];

        UILabel *st = [[UILabel alloc] initWithFrame:CGRectMake(16, 34, cw - 32, 16)];
        st.text = status;
        st.font = [UIFont systemFontOfSize:10];
        st.textColor = [UIColor colorWithWhite:0.6 alpha:1];
        st.textAlignment = NSTextAlignmentCenter;
        [card addSubview:st];

        UILabel *tip = [[UILabel alloc] initWithFrame:CGRectMake(16, 54, cw - 32, 32)];
        tip.text = [LLLUnblockSource helpText];
        tip.numberOfLines = 3;
        tip.font = [UIFont systemFontOfSize:10];
        tip.textColor = [UIColor colorWithWhite:0.5 alpha:1];
        tip.textAlignment = NSTextAlignmentCenter;
        [card addSubview:tip];

        UITextField *f = [[UITextField alloc] initWithFrame:CGRectMake(16, 92, cw - 32, 36)];
        f.backgroundColor = [UIColor colorWithWhite:1 alpha:0.10];
        f.layer.cornerRadius = 10;
        f.textColor = UIColor.whiteColor;
        f.tintColor = LLLAccentColor();
        f.placeholder = @"留空 = 用本地服务";
        f.font = [UIFont systemFontOfSize:12];
        f.autocorrectionType = UITextAutocorrectionTypeNo;
        f.autocapitalizationType = UITextAutocapitalizationTypeNone;
        f.keyboardType = UIKeyboardTypeURL;
        f.text = ext;
        f.leftView = [[UIView alloc] initWithFrame:CGRectMake(0, 0, 10, 36)];
        f.leftViewMode = UITextFieldViewModeAlways;
        [card addSubview:f];
        gUnblockField = f;

        NSArray<NSArray<NSString *> *> *btns = @[
            @[ @"用本地", @"lll4_useLocalUnblock" ],
            @[ @"保存",   @"lll4_saveUnblockBase" ],
            @[ @"关闭",   @"lll4_closeGuestCard" ],
        ];
        CGFloat bw = (cw - 32 - 2 * 8) / 3.0;
        for (NSUInteger i = 0; i < btns.count; i++) {
            UIButton *b = [UIButton buttonWithType:UIButtonTypeSystem];
            b.frame = CGRectMake(16 + i * (bw + 8), 138, bw, 38);
            b.backgroundColor = (i == 1) ? LLLAccentColor()
                                         : [UIColor colorWithWhite:1 alpha:0.10];
            b.layer.cornerRadius = 10;
            [b setTitle:btns[i][0] forState:UIControlStateNormal];
            [b setTitleColor:UIColor.whiteColor forState:UIControlStateNormal];
            b.titleLabel.font = [UIFont systemFontOfSize:13 weight:UIFontWeightMedium];
            [b addTarget:s action:NSSelectorFromString(btns[i][1])
         forControlEvents:UIControlEventTouchUpInside];
            [card addSubview:b];
        }

        UILabel *note = [[UILabel alloc] initWithFrame:CGRectMake(16, 184, cw - 32, 56)];
        note.text = @"· 本地：本机回环服务，不联网也能跑\n"
                     "· 外部：填自己电脑/服务器上的 unblock_server.py 地址";
        note.numberOfLines = 3;
        note.font = [UIFont systemFontOfSize:10];
        note.textColor = [UIColor colorWithWhite:0.45 alpha:1];
        [card addSubview:note];
    });
}

- (void)lll4_useLocalUnblock {
    LLLUnblockServer *srv = [LLLUnblockServer shared];
    [srv setAutoStartEnabled:YES];
    BOOL ok = [srv start];
    [[LLLUnblockSource shared] setBaseURL:nil];   /* 清掉外部地址，走内置通道 */
    gUnblockField.text = @"";
    ShowToast(ok ? @"已切到本地通道" : @"本地服务启动失败", 1.8, YES, !ok);
    PlayHaptic(ok);
}

- (void)lll4_saveUnblockBase {
    NSString *v = gUnblockField.text;
    [[LLLUnblockSource shared] setBaseURL:v];
    ShowToast([[LLLUnblockSource shared] isConfigured] ? @"外部解锁源已保存" : @"已清空，走内置通道",
              1.8, YES, NO);
    PlayHaptic(YES);
}

- (void)lll4_clearUnblockBase {
    [[LLLUnblockSource shared] setBaseURL:nil];
    gUnblockField.text = @"";
    ShowToast(@"已清除", 1.5, YES, NO);
}

- (void)lll4_closeGuestCard {
    if (gGuestClose) { gGuestClose(); gGuestClose = nil; }
    gUnblockField = nil;
    gGuestField = nil;
}

@end
