#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""v2.4/v2.5 累积补丁（幂等）：
2.4  单播放 UI、长按换悬浮图标、版本号
2.5  缓存清理静默、监控数组越界防护、dylib 的 stat/access 隐藏
"""
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
        log.append('SKIP  %s (%s)' % (p, tag))
        return
    wr(p, s.replace(old, new, 1))
    log.append('patch %s (%s)' % (p, tag))

# ============ 2.4 ============
rep('ui/MainViewController.m',
    '    self.musicControlBar.alpha = 1;',
    '    // 2.4: 只留 playerCard 一套播放 UI\n'
    '    self.musicControlBar.hidden = YES;\n    self.musicControlBar.alpha = 0;', 'hide bar')

rep('ui/MainViewController.m', 'bar:self.musicControlBar];', 'bar:nil];', 'bar nil')

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

@implementation FloatingBallView {''', 'top vc')

rep('overlay/FloatMonitor.m',
    '        [self addGestureRecognizer:_pan];',
    '        [self addGestureRecognizer:_pan];\n\n'
    '        UILongPressGestureRecognizer *lp =\n'
    '            [[UILongPressGestureRecognizer alloc] initWithTarget:self action:@selector(longPress:)];\n'
    '        lp.minimumPressDuration = 0.6;\n'
    '        [self addGestureRecognizer:lp];', 'long press')

rep('overlay/FloatMonitor.m',
    '- (void)tap { toggleMainWindow(); }',
    '''- (void)tap { toggleMainWindow(); }

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

rep('core/PluginInfo.h', '#define kPluginVersion @"2.3"', '#define kPluginVersion @"2.5"', 'version')

# ============ 2.5 ============
# 缓存清理：没扫到东西就完全静默（不再每 30s 冒一个胶囊）
rep('core/CacheCleaner.m',
    '''            if (found == 0) {
                [self showDynamicIslandWithTitle:@"无缓存" count:0 isError:NO];
            } else {''',
    '''            if (found == 0) {
                // 2.5: 无缓存时静默，不弹胶囊
            } else {''', 'silent empty')

# 监控面板：数组越界防护
rep('overlay/FloatMonitor.m',
    '        _cpuL = valArr[0]; _memL = valArr[1]; _fpsL = valArr[2];',
    '        if (valArr.count >= 3) { _cpuL = valArr[0]; _memL = valArr[1]; _fpsL = valArr[2]; }',
    'valArr guard')

# 检测规避：隐藏 dylib 的 stat / lstat / access
rep('core/LLLStealth.m',
    '#pragma mark - 文件枚举过滤',
    '''#pragma mark - 裸 stat / access 隐藏

#include <errno.h>
#include <fcntl.h>
#include <sys/stat.h>

static BOOL LLLHideCPath(const char *p) {
    if (!p || !strstr(p, ".dylib")) return NO;
    return strstr(p, "bbhj") || strstr(p, "lll_") || strstr(p, "LLL_") ||
           strstr(p, "MaterialPackManager");
}

static int LLLFakeStat(const char *path, struct stat *buf) {
    if (LLLHideCPath(path)) { errno = ENOENT; return -1; }
    return fstatat(AT_FDCWD, path, buf, 0);
}

static int LLLFakeLstat(const char *path, struct stat *buf) {
    if (LLLHideCPath(path)) { errno = ENOENT; return -1; }
    return fstatat(AT_FDCWD, path, buf, AT_SYMLINK_NOFOLLOW);
}

static int LLLFakeAccess(const char *path, int mode) {
    if (LLLHideCPath(path)) { errno = ENOENT; return -1; }
    return faccessat(AT_FDCWD, path, mode, 0);
}

__attribute__((used)) static const LLLInterpose LLLInterposeStat
    __attribute__((section("__DATA,__interpose"))) = {
        (const void *)&LLLFakeStat, (const void *)&stat };
__attribute__((used)) static const LLLInterpose LLLInterposeLstat
    __attribute__((section("__DATA,__interpose"))) = {
        (const void *)&LLLFakeLstat, (const void *)&lstat };
__attribute__((used)) static const LLLInterpose LLLInterposeAccess
    __attribute__((section("__DATA,__interpose"))) = {
        (const void *)&LLLFakeAccess, (const void *)&access };

#pragma mark - 文件枚举过滤''', 'stat interpose')

for l in log:
    print(l)
