#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
4.0 源码补丁（CI 构建前执行，幂等）。

规则：
  1. 每条补丁带一个唯一标记注释 /* PATCH:xxx */；
  2. 标记已存在 → 跳过（不重复插入）；
  3. 标记不存在且锚点也找不到 → 直接失败（exit 1）。

以前用 `python3 tools/v24.py || true`，锚点丢了也只是默默跳过，
编译能过、bug 还在 —— 这种静默失败比直接报错坑人。
"""
import os
import sys

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))


def rd(rel):
    with open(os.path.join(ROOT, rel), encoding="utf-8") as f:
        return f.read()


def wr(rel, text):
    with open(os.path.join(ROOT, rel), "w", encoding="utf-8") as f:
        f.write(text)


# (文件, 标记, 锚点, 替换成)
PATCHES = [
    (
        "ui/MainViewController.m",
        "PATCH:4.0-mode",
        '        _bgCurrentIndex = [def integerForKey:@"BGCurrentIndex"];\n',
        '        _bgCurrentIndex = [def integerForKey:@"BGCurrentIndex"];\n'
        '\n        /* PATCH:4.0-mode */\n'
        '        NSInteger lllPM = [def integerForKey:@"LLL.playMode"];\n'
        '        if (lllPM >= LLLPlayModeOrder && lllPM <= LLLPlayModeShuffle) {\n'
        '            _playMode = (LLLPlayMode)lllPM;\n'
        '            _loopModeSingle = (_playMode == LLLPlayModeRepeatOne);\n'
        '            _shuffleMode = (_playMode == LLLPlayModeShuffle);\n'
        '        }\n',
    ),
    (
        "ui/MainViewController.m",
        "PATCH:4.0-seg-init",
        '    _musicSrcSeg.selectedSegmentTintColor = LLLAccentColor();\n',
        '    _musicSrcSeg.selectedSegmentTintColor = LLLAccentColor();\n'
        '    /* PATCH:4.0-seg-init */\n'
        '    // 启动停在「材质包」，音源条属于音乐页，一开始就不该露出来\n'
        '    _musicSrcSeg.hidden = YES;\n',
    ),
    (
        "ui/MainViewController.m",
        "PATCH:4.0-seg-switch",
        '    to.hidden = NO;\n'
        '    for (UITableView *v in others) v.hidden = YES;\n'
        '    self.settingsView.hidden = YES;\n',
        '    to.hidden = NO;\n'
        '    for (UITableView *v in others) v.hidden = YES;\n'
        '    self.settingsView.hidden = YES;\n'
        '    /* PATCH:4.0-seg-switch */\n'
        '    // 「本地 / 网易云」只在音乐页出现，否则它会浮在材质包列表上\n'
        '    self.musicSrcSeg.hidden = (to != self.musict);\n',
    ),
    (
        "ui/MainViewController.m",
        "PATCH:4.0-seg-settings",
        '    self.settingsView.userInteractionEnabled = YES;\n',
        '    self.settingsView.userInteractionEnabled = YES;\n'
        '    /* PATCH:4.0-seg-settings */\n'
        '    self.musicSrcSeg.hidden = YES;\n',
    ),
    (
        "ui/MainViewController.m",
        "PATCH:4.0-card-h",
        '    self.playerCard.hidden = NO;\n'
        '    if (self.playerHeight) self.playerHeight.constant = 310;\n',
        '    self.playerCard.hidden = NO;\n'
        '    /* PATCH:4.0-card-h */\n'
        '    // 310 装不下歌词行（内容实际要 322）→ 底部被 clipsToBounds 切掉\n'
        '    if (self.playerHeight) self.playerHeight.constant = 324;\n'
        '    self.musicSrcSeg.hidden = NO;\n',
    ),
    (
        "ui/MainViewController.m",
        "PATCH:4.0-src-reset",
        '    [[NSUserDefaults standardUserDefaults] setInteger:seg.selectedSegmentIndex forKey:@"LLL.musicSource"];\n',
        '    [[NSUserDefaults standardUserDefaults] setInteger:seg.selectedSegmentIndex forKey:@"LLL.musicSource"];\n'
        '    /* PATCH:4.0-src-reset */\n'
        '    // 行数一变 contentOffset 还在原地，看着就像跳到了别的页面\n'
        '    [self.musict setContentOffset:CGPointZero animated:NO];\n',
    ),
]


def main():
    cache = {}
    missing = []
    applied = []

    for rel, tag, anchor, repl in PATCHES:
        if rel not in cache:
            cache[rel] = rd(rel)
        src = cache[rel]

        if tag in src:
            applied.append("skip  %s" % tag)
            continue
        if anchor not in src:
            missing.append("%s -> %s" % (rel, tag))
            continue

        cache[rel] = src.replace(anchor, repl, 1)
        applied.append("patch %s" % tag)

    for rel, text in cache.items():
        if text != rd(rel):
            wr(rel, text)

    print("\n".join(applied))

    if missing:
        print("\n[FAIL] 以下锚点在源码里找不到，补丁没打上：", file=sys.stderr)
        for m in missing:
            print("  - " + m, file=sys.stderr)
        return 1

    return 0


if __name__ == "__main__":
    sys.exit(main())
