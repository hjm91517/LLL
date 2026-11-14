#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""v3.0：音量改数字、缓存文案配色（橙→绿→消隐）、去 emoji、版本号"""
import os
ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
log = []

def rd(p): return open(os.path.join(ROOT,p),encoding='utf-8').read()
def wr(p,s): open(os.path.join(ROOT,p),'w',encoding='utf-8').write(s)
def rep(p,old,new,tag):
    s=rd(p)
    if old not in s: log.append('SKIP %s (%s)'%(p,tag)); return
    wr(p,s.replace(old,new,1)); log.append('patch %s (%s)'%(p,tag))

# 1. 音量图标 → 数字百分比
rep('overlay/LLLMusicIsland.m',
    '''    gVolIcon = [self label:14 weight:UIFontWeightMedium color:[UIColor colorWithWhite:0.85 alpha:1]];
    gVolIcon.text = @"🔊";
    gVolIcon.frame = CGRectMake(18, 138, 24, 26);''',
    '''    gVolIcon = [self label:10 weight:UIFontWeightBold color:[UIColor colorWithWhite:0.9 alpha:1]];
    gVolIcon.font = [UIFont monospacedDigitSystemFontOfSize:10 weight:UIFontWeightBold];
    gVolIcon.textAlignment = NSTextAlignmentCenter;
    gVolIcon.text = [NSString stringWithFormat:@"%d%%", (int)roundf([[NSUserDefaults standardUserDefaults] floatForKey:@"LLL.volume"] * 100)];
    gVolIcon.frame = CGRectMake(10, 138, 34, 26);''', 'vol number')

rep('overlay/LLLMusicIsland.m',
    'gVolSld = [[UISlider alloc] initWithFrame:CGRectMake(46, 140, kExpandW - 64, 26)];',
    'gVolSld = [[UISlider alloc] initWithFrame:CGRectMake(50, 140, kExpandW - 68, 26)];', 'vol slider frame')

rep('overlay/LLLMusicIsland.m',
    '        float v = [[NSUserDefaults standardUserDefaults] floatForKey:@"LLL.volume"];',
    '''        float v = [[NSUserDefaults standardUserDefaults] floatForKey:@"LLL.volume"];
        if (gVolIcon) gVolIcon.text = [NSString stringWithFormat:@"%d%%", (int)roundf(v * 100)];''', 'vol live')

# 2. 缓存文案：去图标（若残留）+ 颜色 + 3s 消隐
rep('overlay/LLLMusicIsland.m', '            [t appendString:@"🧹 "];', '', 'broom')
rep('overlay/LLLMusicIsland.m',
    '''        gCacheLabel.textColor = isError
            ? [UIColor colorWithRed:1 green:0.42 blue:0.42 alpha:1]
            : [UIColor colorWithWhite:0.55 alpha:1];''',
    '''        if (isError) {
            gCacheLabel.textColor = [UIColor colorWithRed:1 green:0.42 blue:0.42 alpha:1];
        } else if ([text containsString:@"已清除"] || [text containsString:@"清理完毕"]) {
            gCacheLabel.textColor = [UIColor colorWithRed:0.30 green:0.85 blue:0.45 alpha:1];
        } else {
            gCacheLabel.textColor = [UIColor colorWithRed:1 green:0.62 blue:0.20 alpha:1];
        }
        [NSObject cancelPreviousPerformRequestsWithTarget:self selector:@selector(clearCacheLabel) object:nil];
        [self performSelector:@selector(clearCacheLabel) withObject:nil afterDelay:3.0];''', 'cache colors')

rep('overlay/LLLMusicIsland.m',
    '+ (void)showCacheStatus:(NSString *)text count:(NSUInteger)count isError:(BOOL)isError {',
    '''+ (void)clearCacheLabel {
    dispatch_async(dispatch_get_main_queue(), ^{
        if (gCacheLabel) gCacheLabel.text = @"";
    });
}

+ (void)showCacheStatus:(NSString *)text count:(NSUInteger)count isError:(BOOL)isError {''', 'clear method')

rep('overlay/LLLMusicIsland.m', '        [self showIsland];', '        /* 不展开，避免遮挡 */', 'no expand')

# 3. 版本
rep('core/PluginInfo.h', '#define kPluginVersion @"2.8"', '#define kPluginVersion @"3.0"', 'v28')
rep('core/PluginInfo.h', '#define kPluginVersion @"2.9"', '#define kPluginVersion @"3.0"', 'v29')

for l in log: print(l)
