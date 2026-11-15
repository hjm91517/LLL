//
//  ui/MainViewController+CloudDaily4.m
//  每日推荐（4.0 新增）。归到 CloudLists4 分类下，与声明同一类别，
//  避免出现「同名 selector 挂在两个分类上」的混乱。
//

#import "MainViewController+CloudLists4.h"
#import "MainViewController+Music4.h"
#import "LLLCloudLogin.h"
#import "LLLMusicController.h"
#import "LLLCloudMusic.h"
#import "LLLUiKit.h"
#import "BaseComponents.h"

@implementation MainViewController (CloudLists4)

- (void)showDailyRecommend {
    if (![LLLCloudMusic shared].loggedIn) {
        ShowToast(@"先登录网易云", 1.6, YES, YES);
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
                ShowToast(err.length ? err : @"今天没有推荐", 1.8, YES, NO);
                [s showLikedSongs];
                return;
            }

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

            LLLShowList(@"每日推荐",
                        [NSString stringWithFormat:@"共 %lu 首", (unsigned long)songs.count],
                        titles, ^(NSInteger idx) {
                if (idx < 0 || idx >= (NSInteger)limit) return;
                [[LLLMusicController shared] playCloudRowDirectly:idx];
                [s lll4_refreshCard];
            });
        });
    }];
}

@end
