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


M = "ui/MainViewController.m"

# (文件, 标记, 锚点, 替换成)
PATCHES = [
    # 1. 启动时把播放模式从偏好里读回来
    (
        M,
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
    # 2. 音源条一开始就隐藏（启动停在材材质包页）
    (
        M,
        "PATCH:4.0-seg-init",
        '    _musicSrcSeg.selectedSegmentTintColor = LLLAccentColor();\n',
        '    _musicSrcSeg.selectedSegmentTintColor = LLLAccentColor();\n'
        '    /* PATCH:4.0-seg-init */\n'
        '    // 启动停在「材质包」，音源条属于音乐页，一开始就不该露出来\n'
        '    _musicSrcSeg.hidden = YES;\n',
    ),
    # 3. 切 tab 时跟着隐现
    (
        M,
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
    # 4. 设置页也不能留
    (
        M,
        "PATCH:4.0-seg-settings",
        '    self.settingsView.userInteractionEnabled = YES;\n',
        '    self.settingsView.userInteractionEnabled = YES;\n'
        '    /* PATCH:4.0-seg-settings */\n'
        '    self.musicSrcSeg.hidden = YES;\n',
    ),
    # 5. 卡片高度 310 → 324（内容实际要 322，歌词行被切了）
    (
        M,
        "PATCH:4.0-card-h",
        '    self.playerCard.hidden = NO;\n'
        '    if (self.playerHeight) self.playerHeight.constant = 310;\n',
        '    self.playerCard.hidden = NO;\n'
        '    /* PATCH:4.0-card-h */\n'
        '    // 310 装不下歌词行（内容实际要 322）→ 底部被 clipsToBounds 切掉\n'
        '    if (self.playerHeight) self.playerHeight.constant = 324;\n'
        '    self.musicSrcSeg.hidden = NO;\n',
    ),
    # 6. 切音源把列表滚回顶部
    (
        M,
        "PATCH:4.0-src-reset",
        '    [[NSUserDefaults standardUserDefaults] setInteger:seg.selectedSegmentIndex forKey:@"LLL.musicSource"];\n',
        '    [[NSUserDefaults standardUserDefaults] setInteger:seg.selectedSegmentIndex forKey:@"LLL.musicSource"];\n'
        '    /* PATCH:4.0-src-reset */\n'
        '    // 行数一变 contentOffset 还在原地，看着就像跳到了别的页面\n'
        '    [self.musict setContentOffset:CGPointZero animated:NO];\n',
    ),
    # 7. 播放按钮不再写死宽度（否则叫 UIStackView 无法等宽）
    (
        M,
        "PATCH:4.0-btn-width",
        '    [b addTarget:self action:action forControlEvents:UIControlEventTouchUpInside];\n'
        '    [b.widthAnchor constraintEqualToConstant:side].active = YES;\n'
        '    [b.heightAnchor constraintEqualToConstant:side].active = YES;\n',
        '    [b addTarget:self action:action forControlEvents:UIControlEventTouchUpInside];\n'
        '    /* PATCH:4.0-btn-width */\n'
        '    // 只钉高度，宽度交给 FillEqually；写死 44/58 时四个键共 250pt，
'
        '    // 而卡片内容宽只有 174pt → 两侧被 clipsToBounds 裁掉，点击热区也没了\n'
        '    [b.heightAnchor constraintEqualToConstant:side].active = YES;\n',
    ),
    # 8. 控制行铺满卡片而不是居中溢出
    (
        M,
        "PATCH:4.0-row-pin",
        '        [row.centerXAnchor constraintEqualToAnchor:_playerCard.centerXAnchor],\n'
        '        [row.topAnchor constraintEqualToAnchor:_playerTimeLabel.bottomAnchor constant:10],\n'
        '        [row.heightAnchor constraintEqualToConstant:58],\n',
        '        /* PATCH:4.0-row-pin */\n'
        '        [row.leadingAnchor constraintEqualToAnchor:_playerCard.leadingAnchor constant:14],\n'
        '        [row.trailingAnchor constraintEqualToAnchor:_playerCard.trailingAnchor constant:-14],\n'
        '        [row.topAnchor constraintEqualToAnchor:_playerTimeLabel.bottomAnchor constant:10],\n'
        '        [row.heightAnchor constraintEqualToConstant:58],\n',
    ),
    # 9. 卡片右上角加网易云登录键
    (
        M,
        "PATCH:4.0-login-btn",
        '    _playerTimeLabel.textAlignment = NSTextAlignmentRight;\n'
        '    [_playerCard addSubview:_playerTimeLabel];\n',
        '    _playerTimeLabel.textAlignment = NSTextAlignmentRight;\n'
        '    [_playerCard addSubview:_playerTimeLabel];\n'
        '\n    /* PATCH:4.0-login-btn */\n'
        '    // 网易云登录入口（原按钮藏在 musicControlBar，2.4 把那栏隐藏后就没入口了）\n'
        '    UIButton *cloudKey = [UIButton buttonWithType:UIButtonTypeSystem];\n'
        '    cloudKey.translatesAutoresizingMaskIntoConstraints = NO;\n'
        '    if (@available(iOS 13.0, *)) {\n'
        '        UIImageSymbolConfiguration *ccfg = [UIImageSymbolConfiguration configurationWithPointSize:11 weight:UIImageSymbolWeightSemibold];\n'
        '        [cloudKey setImage:[UIImage systemImageNamed:@"person.crop.circle" withConfiguration:ccfg] forState:UIControlStateNormal];\n'
        '    }\n'
        '    [cloudKey setTitle:@"登录" forState:UIControlStateNormal];\n'
        '    cloudKey.titleLabel.font = [UIFont systemFontOfSize:9 weight:UIFontWeightSemibold];\n'
        '    cloudKey.titleLabel.adjustsFontSizeToFitWidth = YES;\n'
        '    cloudKey.titleLabel.minimumScaleFactor = 0.6;\n'
        '    cloudKey.contentHorizontalAlignment = UIControlContentHorizontalAlignmentCenter;\n'
        '    cloudKey.tintColor = UIColor.whiteColor;\n'
        '    cloudKey.backgroundColor = LLLAccentColor();\n'
        '    cloudKey.layer.cornerRadius = 13;\n'
        '    cloudKey.layer.cornerCurve = kCACornerCurveContinuous;\n'
        '    cloudKey.clipsToBounds = YES;\n'
        '    [cloudKey addTarget:self action:@selector(openCloudMusic) forControlEvents:UIControlEventTouchUpInside];\n'
        '    _playerCloudBtn = cloudKey;\n'
        '    [_playerCard addSubview:cloudKey];\n'
        '    [NSLayoutConstraint activateConstraints:@[\n'
        '        [cloudKey.trailingAnchor constraintEqualToAnchor:_playerCard.trailingAnchor constant:-12],\n'
        '        [cloudKey.centerYAnchor constraintEqualToAnchor:_playerCover.centerYAnchor],\n'
        '        [cloudKey.widthAnchor constraintEqualToConstant:46],\n'
        '        [cloudKey.heightAnchor constraintEqualToConstant:24]\n'
        '    ]];\n',
    ),
]


def main():
    cache = {}
    missing = []
    log = []

    for rel, tag, anchor, repl in PATCHES:
        if rel not in cache:
            cache[rel] = rd(rel)
        src = cache[rel]

        if tag in src:
            log.append("skip  %s" % tag)
            continue
        if anchor not in src:
            missing.append("%s -> %s" % (rel, tag))
            continue

        cache[rel] = src.replace(anchor, repl, 1)
        log.append("patch %s" % tag)

    for rel, text in cache.items():
        if text != rd(rel):
            wr(rel, text)

    print("\n".join(log) if log else "nothing to do")

    if missing:
        print("\n[FAIL] 以下锚点在源码里找不到，补丁没打上：", file=sys.stderr)
        for m in missing:
            print("  - " + m, file=sys.stderr)
        return 1

    return 0


if __name__ == "__main__":
    sys.exit(main())
