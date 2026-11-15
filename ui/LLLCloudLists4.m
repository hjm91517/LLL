//
//  ui/LLLCloudLists4.m  — 4.0
//  网易云列表：我喜欢的 / 每日推荐 / 搜索。
//  这几方法在 LLLCloudLogin.h 里声明了，必须有人实现，
//  否则 -Wincomplete-implementation 直接编译失败。
//

#import "LLLCloudLogin.h"
#import "MainViewController+Music4.h"
#import "LLLMusicController.h"
#import "LLLCloudMusic.h"
#import "LLLUiKit.h"
#import "BaseComponents.h"
#import <objc/runtime.h>

static UITextField *gLLLSearchField = nil;
static void (^gLLLSearchClose)(void) = nil;
static void *kLLLCloudListRows = &kLLLCloudListRows;

@implementation MainViewController (CloudLists4)

#pragma mark - 我喜欢的

- (void)showLikedSongs {
    if (![LLLCloudMusic shared].loggedIn) {
        ShowToast(@"先登录网易云", 1.6, YES, YES);
        [self presentLoginChooser];
        return;
    }

    ShowToast(@"正在拉取「我喜欢的音乐」…", 1.2, YES, NO);
    __weak typeof(self) w = self;
    [[LLLCloudMusic shared] loadLikedSongs:^(NSArray<NSDictionary *> *songs, NSString *err) {
        dispatch_async(dispatch_get_main_queue(), ^{
            __strong typeof(w) s = w;
            if (!s) return;
            if (!songs.count) {
                ShowToast(err.length ? err : @"列表为空", 2.2, YES, YES);
                PlayHaptic(NO);
                return;
            }
            [s lll4_presentCloudList:songs title:@"我喜欢的音乐"];
        });
    }];
}

#pragma mark - 每日推荐

- (void)showDailyRecommend {
    if (![LLLCloudMusic shared].loggedIn) {
        [self presentLoginChooser];
        return;
    }

    ShowToast(@"正在拉每日推荐…", 1.2, YES, NO);
    __weak typeof(self) w = self;
    [[LLLCloudMusic shared] loadDailyRecommend:^(NSArray<NSDictionary *> *songs, NSString *err) {
        dispatch_async(dispatch_get_main_queue(), ^{
            __strong typeof(w) s = w;
            if (!s) return;
            if (!songs.count) {
                [s showLikedSongs];
                return;
            }
            [s lll4_presentCloudList:songs title:@"每日推荐"];
        });
    }];
}

/// 列表统一入口：灌队列 + 拉面板
- (void)lll4_presentCloudList:(NSArray<NSDictionary *> *)songs title:(NSString *)title {
    if (!songs.count) return;

    NSUInteger limit = MIN(songs.count, (NSUInteger)300);
    NSMutableArray<NSString *> *titles = [NSMutableArray arrayWithCapacity:limit];
    for (NSUInteger i = 0; i < limit; i++) {
        NSDictionary *sg = songs[i];
        NSString *name = sg[@"name"] ?: @"未知";
        NSString *artist = sg[@"artist"] ?: @"";
        [titles addObject:artist.length
                            ? [NSString stringWithFormat:@"%@ - %@", name, artist]
                            : name];
    }

    NSString *msg = (songs.count > limit)
        ? [NSString stringWithFormat:@"共 %lu 首，先显示前 %lu 首",
           (unsigned long)songs.count, (unsigned long)limit]
        : [NSString stringWithFormat:@"共 %lu 首", (unsigned long)songs.count];

    [[LLLMusicController shared] setCloudQueueDirectly:songs];

    __weak typeof(self) w = self;
    LLLShowList(title, msg, titles, ^(NSInteger idx) {
        __strong typeof(w) s = w;
        if (!s) return;
        if (idx < 0 || idx >= (NSInteger)limit) return;
        [[LLLMusicController shared] playCloudRowDirectly:idx];
        [s lll4_refreshCard];
    });
}

#pragma mark - 搜索

- (void)searchCloudMusic {
    if (![LLLCloudMusic shared].loggedIn) {
        ShowToast(@"先登录网易云", 1.5, YES, YES);
        [self presentLoginChooser];
        return;
    }

    LLLShowCustomCard(320, 200, ^(UIView *card, void (^close)(void)) {
        gLLLSearchClose = [close copy];
        CGFloat w = card.bounds.size.width > 1 ? card.bounds.size.width : 320;
        card.frame = CGRectMake(0, 0, w, 156);

        UILabel *t = [[UILabel alloc] initWithFrame:CGRectMake(16, 16, w - 32, 22)];
        t.text = @"搜索网易云音乐";
        t.font = [UIFont systemFontOfSize:15 weight:UIFontWeightSemibold];
        t.textColor = UIColor.whiteColor;
        t.textAlignment = NSTextAlignmentCenter;
        [card addSubview:t];

        UITextField *f = [[UITextField alloc] initWithFrame:CGRectMake(16, 50, w - 32, 38)];
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
        gLLLSearchField = f;

        UIButton *go = [UIButton buttonWithType:UIButtonTypeSystem];
        go.frame = CGRectMake(16, 98, w - 32, 42);
        go.backgroundColor = LLLAccentColor();
        go.layer.cornerRadius = 12;
        [go setTitle:@"搜索" forState:UIControlStateNormal];
        [go setTitleColor:UIColor.whiteColor forState:UIControlStateNormal];
        go.titleLabel.font = [UIFont systemFontOfSize:15 weight:UIFontWeightSemibold];
        [go addTarget:self action:@selector(doCloudSearch) forControlEvents:UIControlEventTouchUpInside];
        [card addSubview:go];
    });
}

- (void)doCloudSearch {
    NSString *kw = [gLLLSearchField.text stringByTrimmingCharactersInSet:
                    [NSCharacterSet whitespaceAndNewlineCharacterSet]];
    if (!kw.length) { ShowToast(@"先输入关键词", 1.5, YES, YES); return; }

    if (gLLLSearchClose) { gLLLSearchClose(); gLLLSearchClose = nil; }
    gLLLSearchField = nil;

    ShowToast(@"搜索中…", 1.2, YES, NO);
    __weak typeof(self) w = self;
    [[LLLCloudMusic shared] searchSongs:kw done:^(NSArray<NSDictionary *> *songs, NSString *err) {
        dispatch_async(dispatch_get_main_queue(), ^{
            __strong typeof(w) s = w;
            if (!s) return;
            if (!songs.count) {
                ShowToast(err.length ? err : @"没搜到", 2, YES, YES);
                return;
            }
            [s lll4_presentCloudList:songs
                               title:[NSString stringWithFormat:@"“%@” 的结果", kw]];
        });
    }];
}

@end
