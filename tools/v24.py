#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""v3.3：v24 的补丁早已并进源码，这里只做幂等补丁。

以前每次 CI 都会无脑往方法里再插一遍「收起播放卡」四行，
再由 "Commit patched sources" 提交回去 —— 每次构建源码都胖一圈。
现在只在标记不存在时才插。
"""
import os

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
log = []


def rd(p):
    with open(os.path.join(ROOT, p), encoding="utf-8") as f:
        return f.read()


def wr(p, s):
    with open(os.path.join(ROOT, p), "w", encoding="utf-8") as f:
        f.write(s)


HIDE = "    self.playerCard.hidden = YES;\n    if (self.playerHeight) self.playerHeight.constant = 0;\n"

path = "ui/MainViewController.m"
src = rd(path)
patched = src

for name in ("showSrcTab", "showQueueTab", "showPluginTab", "showPluginQueueTab"):
    sig = "- (void)%s {\n" % name
    if sig not in patched:
        log.append("SKIP missing %s" % name)
        continue
    if sig + HIDE in patched:
        log.append("already %s" % name)
        continue
    patched = patched.replace(sig, sig + HIDE, 1)
    log.append("patch %s" % name)

if patched != src:
    wr(path, patched)

print("\n".join(log) if log else "nothing to do")
