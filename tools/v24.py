#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""v2.6 补丁（幂等）。v2.4/v2.5 已固化进源码，这里只放新改动：
1) 启动/进度窗口不隐藏 + 非穿透 UIWindow → 卡全屏吞触摸（登录、设置全点不了）
2) 设置页新增「更换悬浮窗图标」入口
3) 悬浮球图标刷新 API
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

# ============ 1. 卡片窗口：穿透 + 用完隐藏 ============
rep('ui/LLLLaunchCard.m',
    'static UIWindow *gLaunchWin = nil;',
    '''static UIWindow *gLaunchWin = nil;

/* 普通 UIWindow 透明全屏常驻会把触摸全吃掉（登录按钮/设置都点不了） */
@interface LLLCardWin : UIWindow @end
@implementation LLLCardWin
- (UIView *)hitTest:(CGPoint)point withEvent:(UIEvent *)event {
    UIView *h = [super hitTest:point withEvent:event];
    if (h == self || (h && h == self.rootViewController.view)) return nil;
    return h;
}
@end''', 'passthrough class')

rep('ui/LLLLaunchCard.m',
    '    gLaunchWin = scene ? [[UIWindow alloc] initWithWindowScene:scene]\n'
    '                       : [[UIWindow alloc] initWithFrame:UIScreen.mainScreen.bounds];',
    '    gLaunchWin = scene ? [[LLLCardWin alloc] initWithWindowScene:scene]\n'
    '                       : [[LLLCardWin alloc] initWithFrame:UIScreen.mainScreen.bounds];',
    'use LLLCardWin')

rep('ui/LLLLaunchCard.m',
    '                                         completion:^(BOOL f) { [card removeFromSuperview]; }];',
    '                                         completion:^(BOOL f) { [card removeFromSuperview]; gLaunchWin.hidden = YES; }];',
    'hide launch win')

rep('ui/LLLLaunchCard.m',
    '''                             completion:^(BOOL f) {
                [card removeFromSuperview];
                [dim removeFromSuperview];
            }];''',
    '''                             completion:^(BOOL f) {
                [card removeFromSuperview];
                [dim removeFromSuperview];
                gLaunchWin.hidden = YES;
            }];''', 'hide progress win')

# ============ 2. 悬浮球：抽 presentIconPicker + C 入口 ============
rep('overlay/FloatMonitor.m',
    '- (void)reloadIcon;\n@end',
    '- (void)reloadIcon;\n- (void)presentIconPicker;\n@end', 'declare picker')

rep('overlay/FloatMonitor.m',
    '''- (void)longPress:(UILongPressGestureRecognizer *)g {
    if (g.state != UIGestureRecognizerStateBegan) return;
    UIViewController *top = LLLTopVC();''',
    '''- (void)longPress:(UILongPressGestureRecognizer *)g {
    if (g.state != UIGestureRecognizerStateBegan) return;
    [self presentIconPicker];
}

- (void)presentIconPicker {
    UIViewController *top = LLLTopVC();''', 'split picker')

rep('overlay/FloatMonitor.m',
    '@implementation FloatingBallView {',
    '''@implementation FloatingBallView {''', 'noop')

s = rd('overlay/FloatMonitor.m')
if 'LLLPresentFloatIconPicker' not in s:
    wr('overlay/FloatMonitor.m', s + '''

void LLLPresentFloatIconPicker(void) {
    if (g_ballView) [g_ballView presentIconPicker];
}
''')
    log.append('append LLLPresentFloatIconPicker')

# ============ 3. 设置页新增入口 ============
rep('ui/MainViewController+SettingsBackground.m',
    '''    [stack addArrangedSubview:cacheCleanerRow];''',
    '''    [stack addArrangedSubview:cacheCleanerRow];

    UIButton *iconBtn = [UIButton buttonWithType:UIButtonTypeSystem];
    iconBtn.translatesAutoresizingMaskIntoConstraints = NO;
    iconBtn.backgroundColor = [UIColor colorWithWhite:1 alpha:0.08];
    iconBtn.layer.cornerRadius = 12;
    [iconBtn setTitle:@"更换悬浮窗图标（相册选图）" forState:UIControlStateNormal];
    [iconBtn setTitleColor:UIColor.whiteColor forState:UIControlStateNormal];
    iconBtn.titleLabel.font = [UIFont systemFontOfSize:14 weight:UIFontWeightMedium];
    [iconBtn addTarget:self action:@selector(lllChangeFloatIcon) forControlEvents:UIControlEventTouchUpInside];
    [stack addArrangedSubview:iconBtn];
    [iconBtn.heightAnchor constraintEqualToConstant:44].active = YES;''', 'icon row')

# ============ 4. 版本 ============
rep('core/PluginInfo.h', '#define kPluginVersion @"2.5"', '#define kPluginVersion @"2.6"', 'version')

for l in log:
    print(l)
