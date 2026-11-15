//
//  ui/MainViewController+GuestPanel4.h
//

#import "MainViewController.h"
#import "MainViewController+Features.h"

NS_ASSUME_NONNULL_BEGIN

@interface MainViewController (GuestPanel4)

- (void)lll4_openGuestMusic;
- (void)lll4_guestSearch;
- (void)lll4_doGuestSearch;
- (void)lll4_guestTopList;
- (void)lll4_presentGuestList:(NSArray<NSDictionary *> *)songs title:(NSString *)title;

/// 解锁音源配置（本地 / 外部）
- (void)lll4_setupUnblockSource;
- (void)lll4_useLocalUnblock;
- (void)lll4_saveUnblockBase;
- (void)lll4_clearUnblockBase;
- (void)lll4_closeGuestCard;

@end

NS_ASSUME_NONNULL_END
