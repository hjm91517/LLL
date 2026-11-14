#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""v2.7：修 RSA 公钥构造失败、登录 803 后抖动、切页残留播放条、岛窗口不隐藏、缓存岛不弹"""
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

# 1. RSA 公钥：补 keySize + PKCS#1 回退
rep('ui/LLLCloudMusic.m',
    '''        NSDictionary *attrs = @{
            (id)kSecAttrKeyType  : (id)kSecAttrKeyTypeRSA,
            (id)kSecAttrKeyClass : (id)kSecAttrKeyClassPublic,
        };
        CFErrorRef err = NULL;
        key = SecKeyCreateWithData((__bridge CFDataRef)spkiSeq, (__bridge CFDictionaryRef)attrs, &err);''',
    '''        NSDictionary *attrs = @{
            (id)kSecAttrKeyType       : (id)kSecAttrKeyTypeRSA,
            (id)kSecAttrKeyClass      : (id)kSecAttrKeyClassPublic,
            (id)kSecAttrKeySizeInBits : @1024,
        };
        CFErrorRef err = NULL;
        key = SecKeyCreateWithData((__bridge CFDataRef)spkiSeq, (__bridge CFDictionaryRef)attrs, &err);
        if (!key) {
            /* SPKI 被拒时退回 PKCS#1（RSAPublicKey SEQUENCE） */
            key = SecKeyCreateWithData((__bridge CFDataRef)seq, (__bridge CFDictionaryRef)attrs, &err);
        }''', 'rsa attrs')

# 2. 803 成功后等 cookie 落地再取账号
rep('ui/LLLCloudMusic.m',
    '''        } else if (code == 803) {
            [s cancelLogin];
            [s fetchAccountThen:''',
    '''        } else if (code == 803) {
            [s cancelLogin];
            [NSThread sleepForTimeInterval:0.4];
            [s fetchAccountThen:''', '803 delay')

# 3. 切页一律收起播放卡片（播放条不再跨页残留）
rep('ui/MainViewController.m',
    '- (void)switchTo:(UIView *)to hide:(NSArray *)hide bar:(UIView *)bar {',
    '''- (void)switchTo:(UIView *)to hide:(NSArray *)hide bar:(UIView *)bar {
    if (to != self.musict) {
        self.playerCard.hidden = YES;
        if (self.playerHeight) self.playerHeight.constant = 0;
    }''', 'hide card on switch')

# 4. 灵动岛隐藏时连窗口一起隐藏（彻底不吞触摸）
rep('overlay/LLLMusicIsland.m',
    '                gPill.hidden = YES;',
    '                gPill.hidden = YES;\n                gWin.hidden = YES;', 'hide win')

# 5. 缓存状态要真的把岛叫出来
rep('overlay/LLLMusicIsland.m',
    '        gCacheLabel.text = t;',
    '        gCacheLabel.text = t;\n        [self showIsland];', 'show island on cache')

# 6. 版本
rep('core/PluginInfo.h', '#define kPluginVersion @"2.6"', '#define kPluginVersion @"2.7"', 'version')

for l in log:
    print(l)
