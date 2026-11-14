#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""v3.1：设置页不可点 —— 清理残留遮罩 + 面板提到最前"""
import os
ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
log = []

def rd(p): return open(os.path.join(ROOT,p),encoding='utf-8').read()
def wr(p,s): open(os.path.join(ROOT,p),'w',encoding='utf-8').write(s)
def rep(p,old,new,tag):
    s=rd(p)
    if old not in s: log.append('SKIP %s (%s)'%(p,tag)); return
    wr(p,s.replace(old,new,1)); log.append('patch %s (%s)'%(p,tag))

rep('ui/MainViewController.m',
    '- (void)showSettingsTab {',
    '''- (void)showSettingsTab {
    /* v3.1: 清掉任何残留的全屏遮罩，并把自己的面板提到最前，否则设置页看着在、其实点不到 */
    for (UIWindow *w in UIApplication.sharedApplication.windows) {
        for (UIView *v in [w.rootViewController.view.subviews copy]) {
            if (v.tag == 99131 || v.tag == 99141) [v removeFromSuperview];
        }
    }
    [self.view bringSubviewToFront:self.settingsView];
    self.settingsView.userInteractionEnabled = YES;''', 'settings front')

rep('core/PluginInfo.h', '#define kPluginVersion @"3.0"', '#define kPluginVersion @"3.1"', 'v30')
rep('core/PluginInfo.h', '#define kPluginVersion @"2.9"', '#define kPluginVersion @"3.1"', 'v29')

for l in log: print(l)
