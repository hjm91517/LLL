//
//  AppTheme.h
//  LLL · 设计系统
//
//  所有颜色 / 圆角 / 间距 / 字号 / 阴影集中在这里。
//  改风格只改这一个文件，别散落到各个 .m 里去。
//

#import <UIKit/UIKit.h>

#pragma mark - 调色板

// —— 基础（旧宏名保留，别的地方还在用）——
#define kCardBackgroundColor        [UIColor colorWithWhite:0.16 alpha:0.55]
#define kCardBorderColor            [UIColor colorWithWhite:0.32 alpha:0.26]
#define kSecondaryTextColor         [UIColor colorWithWhite:0.62 alpha:1.0]
#define kAccentGreen                [UIColor colorWithRed:0.16 green:0.82 blue:0.45 alpha:1.0]
#define kAccentBlue                 [UIColor colorWithRed:0.22 green:0.60 blue:1.00 alpha:1.0]
#define kAccentOrange               [UIColor colorWithRed:0.94 green:0.50 blue:0.10 alpha:1.0]
#define kDestructiveButtonColor     [UIColor colorWithWhite:0.26 alpha:1.0]
#define kHUDOverlayColor            [UIColor colorWithWhite:0.0 alpha:0.45]

// —— 新增 ——
#define kSidebarBackgroundColor     [UIColor colorWithWhite:0.09 alpha:0.62]
#define kContentBackgroundColor     [UIColor colorWithWhite:0.05 alpha:0.38]
#define kBarBackgroundColor         [UIColor colorWithWhite:0.11 alpha:0.92]
#define kTabNormalColor             [UIColor colorWithWhite:0.46 alpha:1.0]
#define kTabActiveColor             UIColor.whiteColor
#define kTabActivePillColor         [UIColor colorWithWhite:1.0 alpha:0.12]
#define kDividerColor               [UIColor colorWithWhite:0.28 alpha:0.42]
#define kEmptyIconColor             [UIColor colorWithWhite:0.28 alpha:1.0]
#define kEmptyTextColor             [UIColor colorWithWhite:0.42 alpha:1.0]

#pragma mark - 几何

#define kCardCornerRadius           16.0
#define kButtonCornerRadius         10.0
#define kMusicControlBarRadius      18.0
#define kFloatingBallRadius         18.0
#define kSidebarCornerRadius        16.0
#define kContentCornerRadius        16.0
#define kPillCornerRadius           10.0

#define kSpaceXS                   4.0
#define kSpaceS                    8.0
#define kSpaceM                    14.0
#define kSpaceL                    20.0
#define kSpaceXL                   28.0

#define kHairline                   0.5

#pragma mark - 字号

#define kTitleFontSize              22.0
#define kCellTitleFontSize          15.0
#define kEmptyStateFontSize         14.0
#define kTabFontSize                10.0
#define kCaptionFontSize            12.0

#pragma mark - 阴影 / 描边

#define kCardShadowOpacity          0.22
#define kCardShadowRadius           14.0
#define kCardShadowOffsetY          4.0

#pragma mark - 内联工具

// 十六进制颜色：LLLHex(0x2E7BFF, 1.0)
static inline UIColor *LLLHex(uint32_t rgb, CGFloat alpha) {
    return [UIColor colorWithRed:((rgb >> 16) & 0xFF) / 255.0
                           green:((rgb >> 8)  & 0xFF) / 255.0
                            blue:( rgb        & 0xFF) / 255.0
                           alpha:alpha];
}

// 统一卡片外观：底色 + 圆角 + 细描边 + 柔和阴影
static inline void LLLCardStyle(UIView *v, CGFloat radius) {
    if (!v) return;
    v.backgroundColor = kCardBackgroundColor;
    v.layer.cornerRadius = radius;
    v.layer.cornerCurve = kCACornerCurveContinuous;
    v.layer.borderWidth = kHairline;
    v.layer.borderColor = kCardBorderColor.CGColor;
    v.clipsToBounds = NO;
    v.layer.shadowColor = UIColor.blackColor.CGColor;
    v.layer.shadowOffset = CGSizeMake(0, kCardShadowOffsetY);
    v.layer.shadowRadius = kCardShadowRadius;
    v.layer.shadowOpacity = kCardShadowOpacity;
    v.layer.masksToBounds = NO;
}

// 整体描边（不想带阴影时用）
static inline void LLLHairlineStyle(UIView *v, CGFloat radius) {
    if (!v) return;
    v.layer.cornerRadius = radius;
    v.layer.cornerCurve = kCACornerCurveContinuous;
    v.layer.borderWidth = kHairline;
    v.layer.borderColor = kCardBorderColor.CGColor;
    v.clipsToBounds = YES;
}

// 发光（选中态 / 强调）
static inline void LLLGlow(UIView *v, UIColor *tint, CGFloat radius, CGFloat opacity) {
    if (!v) return;
    v.layer.shadowColor = (tint ?: UIColor.blackColor).CGColor;
    v.layer.shadowOffset = CGSizeZero;
    v.layer.shadowRadius = radius;
    v.layer.shadowOpacity = opacity;
    v.layer.masksToBounds = NO;
}
