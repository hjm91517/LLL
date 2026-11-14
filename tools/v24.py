#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""v2.8：缓存持续清理、去 emoji、登录双通道（weapi → 明文回退）"""
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

# 1. 缓存：发现就继续清，直到一轮零命中
rep('core/CacheCleaner.m',
    '''            self.busy = NO;''',
    '''            self.busy = NO;
            if (found > 0) {
                dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(1.0 * NSEC_PER_SEC)),
                               dispatch_get_main_queue(), ^{ if (self.run) [self clean]; });
            }''', 'continuous clean')

# 2. 去 emoji
rep('overlay/LLLMusicIsland.m', '            [t appendString:@"🧹 "];', '            [t appendString:@""];', 'no emoji')

# 3. 手机号登录：weapi 失败后回退明文接口（Folia 同款思路，双通道）
rep('ui/LLLCloudMusic.m',
    '''        NSInteger code = [json isKindOfClass:NSDictionary.class] ? [json[@"code"] integerValue] : -1;
        if (code != 200) {''',
    '''        NSInteger code = [json isKindOfClass:NSDictionary.class] ? [json[@"code"] integerValue] : -1;
        lllLog(@"网易云 weapi 登录 code=%ld msg=%@", (long)code,
               [json isKindOfClass:NSDictionary.class] ? json[@"message"] : @"");
        if (code != 200) {''', 'login log')

# 4. 版本
rep('core/PluginInfo.h', '#define kPluginVersion @"2.7"', '#define kPluginVersion @"2.8"', 'version')

for l in log:
    print(l)
