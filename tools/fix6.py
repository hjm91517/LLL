#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""fix6：
1) zip 导入成功后不再删用户原包，改为移到 Caizhi/.zips（避免不可逆丢文件，也避免反复导入）
2) 灵动岛 updateTitle: 不再强行把展开态收起来（否则本地播放每更新一次就塌）
"""
import os

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))

# ---- zip ----
p = os.path.join(ROOT, 'core/LLLZip.m')
with open(p, encoding='utf-8') as f:
    s = f.read()

old = '''            if ([fm moveItemAtPath:src toPath:target error:&mvErr]) {
                ok++;
                lllLog(@"ZIP 导入: %@", name);
                [fm removeItemAtPath:zip error:nil];
            } else {'''
new = '''            if ([fm moveItemAtPath:src toPath:target error:&mvErr]) {
                ok++;
                lllLog(@"ZIP 导入: %@", name);
                // 不删用户文件，只归到 .zips 里，避免每次启动重复导入
                NSString *done = [caizhi stringByAppendingPathComponent:@".zips"];
                [fm createDirectoryAtPath:done withIntermediateDirectories:YES attributes:nil error:nil];
                [fm moveItemAtPath:zip
                            toPath:[done stringByAppendingPathComponent:zip.lastPathComponent]
                             error:nil];
            } else {'''

if old in s:
    s = s.replace(old, new, 1)
    with open(p, 'w', encoding='utf-8') as f:
        f.write(s)
    print('zip: non-destructive import')
else:
    print('zip: anchor missing')

# ---- island ----
p = os.path.join(ROOT, 'overlay/LLLMusicIsland.m')
with open(p, encoding='utf-8') as f:
    s = f.read()

old = '''            gLegacyTitle = [title copy];
            gLegacyPlaying = playing;
            gExpanded = NO;
            [self showIsland];'''
new = '''            gLegacyTitle = [title copy];
            gLegacyPlaying = playing;
            [self showIsland];'''

if old in s:
    s = s.replace(old, new, 1)
    with open(p, 'w', encoding='utf-8') as f:
        f.write(s)
    print('island: keep expanded state')
else:
    print('island: anchor missing')
