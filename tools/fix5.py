#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""fix5：fix4 把定义里的 LLLCardX 也改成了 LLLLCardX（子串误伤），
这里把四个 L 统一收回三个。"""
import os

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
p = os.path.join(ROOT, 'ui/LLLLaunchCard.m')

with open(p, encoding='utf-8') as f:
    s = f.read()

for wrong, right in (('LLLLCardWindow', 'LLLCardWindow'),
                     ('LLLLCardDim', 'LLLCardDim'),
                     ('LLLLCardBox', 'LLLCardBox'),
                     ('LLLLCardRing', 'LLLCardRing')):
    n = s.count(wrong)
    if n:
        s = s.replace(wrong, right)
        print('fix', wrong, '->', right, 'x', n)
    else:
        print('skip', wrong)

with open(p, 'w', encoding='utf-8') as f:
    f.write(s)

# 自检：定义与调用必须同名
import re
for name in ('LLLCardWindow', 'LLLCardDim', 'LLLCardBox', 'LLLRing'):
    print(name, 'occurrences =', len(re.findall(name + r'\b', s)))
