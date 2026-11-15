//
//  ui/LLLGuestPanel.m
//  免登录入口：搜索 / 飙升榜 / 解锁音源配置。
//

#import <UIKit/UIKit.h>
#import "MainViewController.h"
#import "MainViewController+GuestPanel4.h"
#import "MainViewController+Music4.h"
#import "MainViewController+CloudLists4.h"
#import "LLLCloudLogin.h"
#import "LLLGuestMusic.h"
#import "LLLUnblockSource.h"
#import "LLLMusicController.h"
#import "LLLCloudMusic.h"
#import "LLLUiKit.h"
#import "BaseComponents.h"
#import "AppTheme.h"

static UITextField *gGuestField = nil;
static void (^gGuestClose)(void) = nil;
static UITextField *gUnblockField = nil;

@implementation MainViewController (GuestPanel4)

- (void)lll4_openGuestMusic {
    __weak typeof(self) w = self;
    BOOL hasUnblock = [[LLLUnblockSource shared] isConfigured];
    NSString *unblockTitle = hasUnblock ? @"解锁音源（已配置）" : @"解锁音源（会员曲）";

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
    LLLShowCustomCard(320, 260, ^(UIView *card, void (^close)(void)) {
        __strong typeof(w) s = w;
        if (!s) return;

        gGuestClose = [close copy];
        CGFloat cw = card.bounds.size.width > 1 ? card.bounds.size.width : 320;
        card.frame = CGRectMake(0, 0, cw, 216);

        UILabel *t = [[UILabel alloc] initWithFrame:CGRectMake(16, 14, cw - 32, 20)];
        t.text = @"解锁音源（会员曲换源）";
        t.font = [UIFont systemFontOfSize:14 weight:UIFontWeightSemibold];
        t.textColor = UIColor.whiteColor;
        t.textAlignment = NSTextAlignmentCenter;
        [card addSubview:t];

        UILabel *tip = [[UILabel alloc] initWithFrame:CGRectMake(16, 36, cw - 32, 34)];
        tip.text = [LLLUnblockSource helpText];
        tip.numberOfLines = 2;
        tip.font = [UIFont systemFontOfSize:10];
        tip.textColor = [UIColor colorWithWhite:0.55 alpha:1];
        tip.textAlignment = NSTextAlignmentCenter;
        [card addSubview:tip];

        UITextField *f = [[UITextField alloc] initWithFrame:CGRectMake(16, 76, cw - 32, 38)];
        f.backgroundColor = [UIColor colorWithWhite:1 alpha:0.10];
        f.layer.cornerRadius = 10;
        f.textColor = UIColor.whiteColor;
        f.tintColor = LLLAccentColor();
        f.placeholder = @"http://192.168.1.10:8080";
        f.font = [UIFont systemFontOfSize:13];
        f.autocorrectionType = UITextAutocorrectionTypeNo;
        f.autocapitalizationType = UITextAutocapitalizationTypeNone;
        f.keyboardType = UIKeyboardTypeURL;
        f.text = [[LLLUnblockSource shared] baseURL];
        f.leftView = [[UIView alloc] initWithFrame:CGRectMake(0, 0, 12, 38)];
        f.leftViewMode = UITextFieldViewModeAlways;
        [card addSubview:f];
        gUnblockField = f;

        UIButton *save = [UIButton buttonWithType:UIButtonTypeSystem];
        save.frame = CGRectMake(16, 124, (cw - 44) / 2, 40);
        save.backgroundColor = LLLAccentColor();
        save.layer.cornerRadius = 12;
        [save setTitle:@"保存" forState:UIControlStateNormal];
        [save setTitleColor:UIColor.whiteColor forState:UIControlStateNormal];
        save.titleLabel.font = [UIFont systemFontOfSize:15 weight:UIFontWeightSemibold];
        [save addTarget:s action:@selector(lll4_saveUnblockBase)
       forControlEvents:UIControlEventTouchUpInside];
        [card addSubview:save];

        UIButton *clear = [UIButton buttonWithType:UIButtonTypeSystem];
        clear.frame = CGRectMake(16 + (cw - 44) / 2 + 12, 124, (cw - 44) / 2, 40);
        clear.backgroundColor = [UIColor colorWithWhite:1 alpha:0.10];
        clear.layer.cornerRadius = 12;
        [clear setTitle:@"清除" forState:UIControlStateNormal];
        [clear setTitleColor:[UIColor colorWithWhite:0.8 alpha:1] forState:UIControlStateNormal];
        clear.titleLabel.font = [UIFont systemFontOfSize:15 weight:UIFontWeightMedium];
        [clear addTarget:s action:@selector(lll4_clearUnblockBase)
        forControlEvents:UIControlEventTouchUpInside];
        [card addSubview:clear];

        UIButton *cancel = [UIButton buttonWithType:UIButtonTypeSystem];
        cancel.frame = CGRectMake(16, 170, cw - 32, 34);
        cancel.backgroundColor = [UIColor colorWithWhite:1 alpha:0.06];
        cancel.layer.cornerRadius = 10;
        [cancel setTitle:@"关闭" forState:UIControlStateNormal];
        [cancel setTitleColor:[UIColor colorWithWhite:0.7 alpha:1] forState:UIControlStateNormal];
        cancel.titleLabel.font = [UIFont systemFontOfSize:14];
        [cancel addTarget:s action:@selector(lll4_closeGuestCard)
        forControlEvents:UIControlEventTouchUpInside];
        [card addSubview:cancel];
    });
}

- (void)lll4_saveUnblockBase {
    NSString *v = gUnblockField.text;
    [[LLLUnblockSource shared] setBaseURL:v];
    ShowToast([[LLLUnblockSource shared] isConfigured] ? @"解锁源已保存" : @"已清空",
              1.6, YES, NO);
    PlayHaptic(YES);
}

- (void)lll4_clearUnblockBase {
    [[LLLUnblockSource shared] setBaseURL:nil];
    gUnblockField.text = @"";
    ShowToast(@"已清除解锁源", 1.5, YES, NO);
}

- (void)lll4_closeGuestCard {
    if (gGuestClose) { gGuestClose(); gGuestClose = nil; }
    gUnblockField = nil;
}

@end
