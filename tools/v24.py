#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""v2.9：缓存文案去图标/橙→绿→消隐，岛不展开不挡手，音量显示数字，登录按 Folia 思路（cookie 优先）"""
import os
ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
log = []

def rd(p): return open(os.path.join(ROOT,p),encoding='utf-8').read()
def wr(p,s): open(os.path.join(ROOT,p),'w',encoding='utf-8').write(s)
def rep(p,old,new,tag):
    s=rd(p)
    if old not in s: log.append('SKIP %s (%s)'%(p,tag)); return
    wr(p,s.replace(old,new,1)); log.append('patch %s (%s)'%(p,tag))

# 1. 去清扫图标 + 橙/绿配色 + 3s 后自动清空
rep('overlay/LLLMusicIsland.m',
    '            [t appendString:@"🧹 "];', '', 'broom')

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

# 2. 缓存状态不展开岛（避免大面积遮挡）
rep('overlay/LLLMusicIsland.m', '        [self showIsland];', '        /* v2.9: 只更新胶囊文字，不展开、不遮挡 */', 'no expand')

# 3. 铃叭→ 数字音量
rep('overlay/LLLMusicIsland.m',
    '''        float v = [[NSUserDefaults standardUserDefaults] floatForKey:@"LLL.volume"];''',
    '''        float v = [[NSUserDefaults standardUserDefaults] floatForKey:@"LLL.volume"];
        gVolLabel.text = [NSString stringWithFormat:@"%d%%", (int)roundf(v * 100)];
        gVolLabel.font = [UIFont monospacedDigitSystemFontOfSize:10 weight:UIFontWeightBold];
        gVolLabel.textColor = [UIColor colorWithWhite:0.9 alpha:1];
        gVolLabel.textAlignment = NSTextAlignmentCenter;''', 'vol label')

# 4. 登录：cookie 优先（Folia 思路），有 MUSIC_U 直接跳过扫码
rep('ui/LLLCloudLogin.m',
    '    LLLCloudMusic *cm = [LLLCloudMusic shared];\n    if (cm.loggedIn) {',
    '''    LLLCloudMusic *cm = [LLLCloudMusic shared];
    if (!cm.loggedIn) [cm restoreCookieSession];   /* Folia 思路：本地 cookie 先复活会话 */
    if (cm.loggedIn) {''', 'cookie restore')

# 5. 版本
rep('core/PluginInfo.h', '#define kPluginVersion @"2.8"', '#define kPluginVersion @"2.9"', 'version')

for l in log: print(l)
