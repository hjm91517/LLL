#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""v2.9（安全版）：去清扫图标、橙→绿→消隐、缓存不展开不遮挡、版本号"""
import os
ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
log = []

def rd(p): return open(os.path.join(ROOT,p),encoding='utf-8').read()
def wr(p,s): open(os.path.join(ROOT,p),'w',encoding='utf-8').write(s)
def rep(p,old,new,tag):
    s=rd(p)
    if old not in s: log.append('SKIP %s (%s)'%(p,tag)); return
    wr(p,s.replace(old,new,1)); log.append('patch %s (%s)'%(p,tag))

# 1. 去清扫图标
rep('overlay/LLLMusicIsland.m', '            [t appendString:@"🧹 "];', '', 'broom')

# 2. 颜色：发现=橙，已清除=绿，错误=红；3s 后清空
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

# 3. 不展开岛，避免大面积遮挡
rep('overlay/LLLMusicIsland.m', '        [self showIsland];', '        /* v2.9: 只更新胶囊文字，不展开、不遮挡 */', 'no expand')

# 4. 版本
rep('core/PluginInfo.h', '#define kPluginVersion @"2.8"', '#define kPluginVersion @"2.9"', 'version')

for l in log: print(l)
