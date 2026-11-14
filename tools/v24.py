#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""v2.4：
1) 音乐页只留一份播放 UI（playerCard），隐藏旧底部 musicControlBar
2) 悬浮球长按换图标（相册选图 → Documents/bbhj_icon.png → 即时重载）
3) 版本号 2.4
幂等：拿不到锚点就跳过。"""
import os

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
log = []

def rd(p):
    with open(os.path.join(ROOT, p), encoding='utf-8') as f:
        return f.read()

def wr(p, s):
    with open(os.path.join(ROOT, p), 'w', encoding='utf-8') as f:
        f.write(s)

def rep(p, old, new, tag):
    s = rd(p)
    if old not in s:
        log.append('skip  %s (%s)' % (p, tag))
        return
    wr(p, s.replace(old, new, 1))
    log.append('patch %s (%s)' % (p, tag))

# ---------- 1. 去掉重复播放 UI ----------
rep('ui/MainViewController.m',
    '    self.musicControlBar.alpha = 1;',
    '    // v2.4: 只留 playerCard 一套播放 UI，旧底部控制栏彻底隐藏\n'
    '    self.musicControlBar.hidden = YES;\n    self.musicControlBar.alpha = 0;', 'hide control bar')

rep('ui/MainViewController.m',
    'bar:self.musicControlBar];',
    'bar:nil];', 'music tab bar nil')

# ---------- 2. 悬浮球长按换图标 ----------
rep('overlay/FloatMonitor.m',
    '@implementation FloatingBallView {',
    '''static UIViewController *LLLTopVC(void) {
    UIWindow *win = nil;
    if (@available(iOS 13.0, *)) {
        for (UIScene *s in UIApplication.sharedApplication.connectedScenes) {
            if ([s isKindOfClass:UIWindowScene.class] &&
                s.activationState == UISceneActivationStateForegroundActive) {
                win = ((UIWindowScene *)s).windows.firstObject;
                break;
            }
        }
    }
    if (!win) win = UIApplication.sharedApplication.keyWindow;
    UIViewController *vc = win.rootViewController;
    while (vc.presentedViewController) vc = vc.presentedViewController;
    return vc;
}

@interface FloatingBallView () <UIImagePickerControllerDelegate, UINavigationControllerDelegate>
- (void)longPress:(UILongPressGestureRecognizer *)g;
- (void)reloadIcon;
@end

@implementation FloatingBallView {''', 'top vc + delegate')

rep('overlay/FloatMonitor.m',
    '        [self addGestureRecognizer:_pan];',
    '        [self addGestureRecognizer:_pan];\n\n'
    '        UILongPressGestureRecognizer *lp =\n'
    '            [[UILongPressGestureRecognizer alloc] initWithTarget:self action:@selector(longPress:)];\n'
    '        lp.minimumPressDuration = 0.6;\n'
    '        lp.cancelsTouchesInView = YES;\n'
    '        [self addGestureRecognizer:lp];', 'long press')

rep('overlay/FloatMonitor.m',
    '- (void)tap { toggleMainWindow(); }',
    '''- (void)tap { toggleMainWindow(); }

#pragma mark - 自定义图标

- (void)longPress:(UILongPressGestureRecognizer *)g {
    if (g.state != UIGestureRecognizerStateBegan) return;
    UIViewController *top = LLLTopVC();
    if (!top || top.isBeingDismissed) return;
    if (![UIImagePickerController isSourceTypeAvailable:UIImagePickerControllerSourceTypePhotoLibrary]) return;

    UIImagePickerController *p = [UIImagePickerController new];
    p.sourceType = UIImagePickerControllerSourceTypePhotoLibrary;
    p.delegate = self;
    p.allowsEditing = YES;
    [top presentViewController:p animated:YES completion:nil];
}

- (void)imagePickerController:(UIImagePickerController *)picker
        didFinishPickingMediaWithInfo:(NSDictionary<UIImagePickerControllerInfoKey, id> *)info {
    UIImage *img = info[UIImagePickerControllerEditedImage] ?: info[UIImagePickerControllerOriginalImage];
    [picker dismissViewControllerAnimated:YES completion:nil];
    if (!img) return;

    // 统一缩到 256x256，不占空间也不糊
    UIGraphicsBeginImageContextWithOptions(CGSizeMake(256, 256), NO, 1);
    [img drawInRect:CGRectMake(0, 0, 256, 256)];
    UIImage *out = UIGraphicsGetImageFromCurrentImageContext();
    UIGraphicsEndImageContext();

    NSString *path = [docsPath() stringByAppendingPathComponent:@"bbhj_icon.png"];
    BOOL ok = [UIImagePNGRepresentation(out ?: img) writeToFile:path atomically:YES];
    [self reloadIcon];
    ShowToast(ok ? @"悬浮窗图标已更新" : @"图标保存失败", 1.6, YES, !ok);
}

- (void)imagePickerControllerDidCancel:(UIImagePickerController *)picker {
    [picker dismissViewControllerAnimated:YES completion:nil];
}

- (void)reloadIcon {
    UIImage *custom = customFloatIcon();
    [_btn setImage:(custom ?: floatIcon()) forState:UIControlStateNormal];
    _btn.imageView.contentMode = UIViewContentModeScaleAspectFill;
}''', 'icon picker')

# ---------- 3. 版本号 ----------
rep('core/PluginInfo.h', '#define kPluginVersion @"2.3"', '#define kPluginVersion @"2.4"', 'version')

for l in log:
    print(l)
