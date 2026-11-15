//
//  ui/LLLCloudLists4.m
//  4.0 网易云列表页：我喜欢的 / 每日推荐 / 搜索
//  统一走 LLLMusicController 的队列，点一行就进内核播放。
//

#import "LLLCloudLogin.h"
#import "MainViewController+Features.h"
#import "MainViewController+Music4.h"
#import "LLLMusicController.h"
#import "LLLCloudMusic.h"
#import "LLLUiKit.h"
#import "BaseComponents.h"

@implementation MainViewController (CloudLists4)

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
                /* 每日推荐拿不到就退回喜欢的列表，别让人对着空面板 */
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

    /* 一次最多渲染 300 条：上千个按钮会把主线程干死 */
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

    /* 队列给内核：之后顺序/随机/上一首下一首都由内核负责 */
    [[LLLMusicController shared] setCloudQueueDirectly:songs];

    __weak typeof(self) w = self;
    LLLShowList(title, msg, titles, ^(NSInteger idx) {
        __strong typeof(w) s = w;
        if (!s) return;
        if (idx < 0 || idx >= (NSInteger)limit) return;
        [[LLLMusicController shared] playCloudRowDirectly:idx];
        [s lll4_refreshCard];
        [s.musict reloadData];
    });
}

@end
