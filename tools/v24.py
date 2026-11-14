#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""v3.2：每个非音乐页进入时都收起播放卡片（不再依赖 switchTo 单点）"""
import os
ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
log=[]
def rd(p): return open(os.path.join(ROOT,p),encoding='utf-8').read()
def wr(p,s): open(os.path.join(ROOT,p),'w',encoding='utf-8').write(s)
def rep(p,old,new,t):
    s=rd(p)
    if old not in s: log.append('SKIP %s'%t); return
    wr(p,s.replace(old,new,1)); log.append('patch %s'%t)

p='ui/MainViewController.m'
hide = '''    self.playerCard.hidden = YES;
    if (self.playerHeight) self.playerHeight.constant = 0;
'''
for name in ('showSrcTab','showQueueTab','showPluginTab','showPluginQueueTab'):
    rep(p, '- (void)%s {' % name, '- (void)%s {\n%s' % (name, hide), name)

rep('core/PluginInfo.h', '#define kPluginVersion @"3.1"', '#define kPluginVersion @"3.2"', 'v31')
rep('core/PluginInfo.h', '#define kPluginVersion @"3.0"', '#define kPluginVersion @"3.2"', 'v30')
rep('core/PluginInfo.h', '#define kPluginVersion @"2.9"', '#define kPluginVersion @"3.2"', 'v29')
for l in log: print(l)
