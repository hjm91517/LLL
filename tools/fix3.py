#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""fix3：applyVolume / startProgressTimer 在 MainViewController_Private.h 里，
分类里看不到；就地补个声明。"""
import os

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
p = os.path.join(ROOT, 'ui/LLLCloudLogin.m')

with open(p, encoding='utf-8') as f:
    s = f.read()

anchor = '#import <AVFoundation/AVFoundation.h>\n'
block = ('#import <AVFoundation/AVFoundation.h>\n\n'
         '@interface MainViewController (LLLCloudPrivate)\n'
         '- (void)applyVolume;\n'
         '- (void)startProgressTimer;\n'
         '@end\n')

if 'LLLCloudPrivate' in s:
    print('already patched')
elif anchor in s:
    s = s.replace(anchor, block, 1)
    with open(p, 'w', encoding='utf-8') as f:
        f.write(s)
    print('patched declarations')
else:
    print('anchor missing')
