#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""fix2：AppTheme.h 里已经有 static inline LLLHex(uint32_t, CGFloat)，
LLLCloudMusic 的十六进制工具重名了，改名 LLLHexStr。"""
import os

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
p = os.path.join(ROOT, 'ui/LLLCloudMusic.m')

with open(p, encoding='utf-8') as f:
    s = f.read()

pairs = [
    ('static NSString *LLLHex(NSData *d) {', 'static NSString *LLLHexStr(NSData *d) {'),
    ('LLLHex((__bridge NSData *)out)', 'LLLHexStr((__bridge NSData *)out)'),
]
for a, b in pairs:
    if a in s:
        s = s.replace(a, b)
        print('rename', a[:40])
    else:
        print('skip', a[:40])

with open(p, 'w', encoding='utf-8') as f:
    f.write(s)
