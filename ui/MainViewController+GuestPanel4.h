//
//  ui/MainViewController+GuestPanel4.h
//  免登录面板的声明。实现在 LLLGuestPanel.m 的 (GuestPanel4) 分类里。
//  声明与实现必须同一分类名，否则 -Wincomplete-implementation 会报错。
//

#import "MainViewController.h"

NS_ASSUME_NONNULL_BEGIN

@interface MainViewController (GuestPanel4)

- (void)lll4_openGuestMusic;
- (void)lll4_guestSearch;
- (void)lll4_doGuestSearch;
- (void)lll4_guestTopList;
- (void)lll4_presentGuestList:(NSArray<NSDictionary *> *)songs title:(NSString *)title;

@end

NS_ASSUME_NONNULL_END
