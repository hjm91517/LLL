#import "LLLBrandArt.h"

static UIImage *gLLLBrand = nil;

static UIImage *LLLDrawBrandFallback(void) {
    CGSize s = CGSizeMake(72, 72);
    UIGraphicsImageRendererFormat *fmt = [UIGraphicsImageRendererFormat defaultFormat];
    fmt.opaque = NO;
    UIGraphicsImageRenderer *r = [[UIGraphicsImageRenderer alloc] initWithSize:s format:fmt];
    return [r imageWithActions:^(UIGraphicsImageRendererContext *ctx) {
        CGContextRef c = ctx.CGContext;
        /* 红底圆 */
        CGContextSetFillColorWithColor(c, [UIColor colorWithRed:0.87 green:0.10 blue:0.15 alpha:1.0].CGColor);
        CGContextFillEllipseInRect(c, CGRectMake(0, 0, s.width, s.height));

        /* 白音符：优先 SF Symbol，取不到就手绘一个 */
        UIImage *note = nil;
        if (@available(iOS 13.0, *)) {
            note = [UIImage systemImageNamed:@"music.note"];
            note = [note imageWithTintColor:UIColor.whiteColor
                              renderingMode:UIImageRenderingModeAlwaysOriginal];
        }
        if (note) {
            CGFloat side = s.width * 0.56;
            [note drawInRect:CGRectMake((s.width - side) / 2.0,
                                        (s.height - side) / 2.0, side, side)];
            return;
        }
        /* 手绘兜底：一根符干 + 一个符头 */
        CGContextSetFillColorWithColor(c, UIColor.whiteColor.CGColor);
        CGContextFillEllipseInRect(c, CGRectMake(s.width * 0.32, s.height * 0.56,
                                                 s.width * 0.22, s.height * 0.18));
        CGContextFillRect(c, CGRectMake(s.width * 0.50, s.height * 0.26,
                                        s.width * 0.05, s.height * 0.34));
        CGContextFillRect(c, CGRectMake(s.width * 0.50, s.height * 0.26,
                                        s.width * 0.16, s.height * 0.05));
    }];
}

UIImage *LLLCloudBrandImage(void) {
    if (gLLLBrand) return gLLLBrand;

    NSMutableArray<NSString *> *cands = [NSMutableArray array];
    NSString *bundlePath = [[NSBundle mainBundle] pathForResource:@"LLLCloudBrand" ofType:@"png"];
    if (bundlePath.length) [cands addObject:bundlePath];
    NSString *docs = NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES).firstObject;
    if (docs.length) {
        [cands addObject:[docs stringByAppendingPathComponent:@"LLLCloudBrand.png"]];
        [cands addObject:[docs stringByAppendingPathComponent:@"music/LLLCloudBrand.png"]];
    }
    for (NSString *p in cands) {
        UIImage *img = [UIImage imageWithContentsOfFile:p];
        if (img) { gLLLBrand = img; return gLLLBrand; }
    }

    gLLLBrand = LLLDrawBrandFallback();
    return gLLLBrand;
}
