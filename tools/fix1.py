#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""fix1：网易云方法已搬到 LLLCloudLogin 分类，Features.h 里的旧声明要删掉，
否则 -Wincomplete-implementation 会把 (Features) 分类判死。"""
import os

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
p = os.path.join(ROOT, 'ui/MainViewController+Features.h')

with open(p, encoding='utf-8') as f:
    s = f.read()

for line in ('- (void)openCloudMusic;\n', '- (void)playCloudSong:(NSDictionary *)song;\n'):
    if line in s:
        s = s.replace(line, '', 1)
        print('remove', line.strip())
    else:
        print('skip', line.strip())

with open(p, 'w', encoding='utf-8') as f:
    f.write(s)
