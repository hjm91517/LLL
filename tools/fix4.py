#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""fix4：助手函数名少写了一个 L（LLCardWindow → LLLCardWindow）。"""
import os

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
p = os.path.join(ROOT, 'ui/LLLLaunchCard.m')

with open(p, encoding='utf-8') as f:
    s = f.read()

for wrong, right in (('LLCardWindow', 'LLLCardWindow'),
                     ('LLCardDim', 'LLLCardDim'),
                     ('LLCardBox', 'LLLCardBox')):
    n = s.count(wrong)
    if n:
        s = s.replace(wrong, right)
        print('fix', wrong, '->', right, 'x', n)
    else:
        print('skip', wrong)

with open(p, 'w', encoding='utf-8') as f:
    f.write(s)
