//
//  ui/LLLMusicTab4.m
//  4.0 音乐页表格数据源（分类扩展，统一从 LLLMusicController 取数）。
//
//  老实现里 numberOfRows 和 cellForRow 分别读 _musicSrcSeg 和自己缓存的数组；
//  分段控件被改、数组没跟上就会越界 → 页面错乱/跳转。
//  现在两个方法只有一个取数入口，越界不可能发生。
//

#import <UIKit/UIKit.h>
#import <objc/runtime.h>            /* objc_setAssociatedObject */
#import "MainViewController.h"
#import "MainViewController_Private.h"
#import "MainViewController+Music4.h"
#import "LLLMusicController.h"
#import "LLLCloudMusic.h"
#import "BaseComponents.h"
#import "AppTheme.h"

@implementation MainViewController (MusicTab4)

- (NSInteger)lll4_musicRows {
    return [[LLLMusicController shared] rowCount];
}

/// 表格里点播放 / 点行，宿主调用它
- (void)lll4_playMusicRow:(NSInteger)row {
    [[LLLMusicController shared] playRow:row];
    [self.musict reloadData];
    [self lll4_refreshCard];
}

/// 给 cell 填内容（宿主 cellForRow 里对 musict 调它）
- (void)lll4_configureMusicCell:(UITableViewCell *)cell row:(NSInteger)row {
    LLLMusicController *mc = [LLLMusicController shared];
    NSDictionary *info = [mc rowInfoAt:row];
    if (!info) return;

    if ([cell isKindOfClass:NSClassFromString(@"PackCell")]) {
        id c = cell;
        UILabel *title = [c valueForKey:@"title"];
        UILabel *sub = [c valueForKey:@"sub"];
        UIImageView *icon = [c valueForKey:@"icon"];
        UIButton *btn = [c valueForKey:@"btn"];

        title.text = info[@"name"] ?: @"";
        title.adjustsFontSizeToFitWidth = YES;
        title.minimumScaleFactor = 0.6;
        sub.text = info[@"artist"] ?: @"";

        BOOL cloud = ([mc sourceKind] == LLLMusicSourceKindCloud);
        if (@available(iOS 13.0, *)) {
            icon.image = [UIImage systemImageNamed:(cloud ? @"cloud.fill" : @"music.note")];
            icon.tintColor = cloud ? [UIColor colorWithRed:0.86 green:0.24 blue:0.24 alpha:1]
                                   : kAccentGreen;
            icon.contentMode = UIViewContentModeCenter;
        }

        [btn setImage:[UIImage systemImageNamed:@"play.circle.fill"] forState:UIControlStateNormal];
        [btn removeTarget:self action:NULL forControlEvents:UIControlEventTouchUpInside];
        [btn addTarget:self action:@selector(lll4_musicCellPlay:)
      forControlEvents:UIControlEventTouchUpInside];
        objc_setAssociatedObject(btn, "idx", @(row), OBJC_ASSOCIATION_RETAIN);
    }
}

@end
