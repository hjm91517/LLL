#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""v2 源码补丁：把已有文件改到 v2（幂等，重复跑会跳过）。"""
import os

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
logs = []

def path(rel):
    return os.path.join(ROOT, rel)

def read(rel):
    with open(path(rel), encoding='utf-8') as f:
        return f.read()

def write(rel, s):
    with open(path(rel), 'w', encoding='utf-8') as f:
        f.write(s)

def rep(rel, old, new, tag=''):
    s = read(rel)
    if old not in s:
        logs.append('skip %s (%s)' % (rel, tag or old[:28].replace('\n', ' ')))
        return
    write(rel, s.replace(old, new, 1))
    logs.append('patch %s (%s)' % (rel, tag))

def cut(rel, start, end, tag=''):
    s = read(rel)
    a = s.find(start)
    if a < 0:
        logs.append('skip %s (cut %s)' % (rel, tag))
        return
    b = s.find(end, a)
    if b < 0:
        logs.append('MISS %s (cut end %s)' % (rel, tag))
        return
    write(rel, s[:a] + s[b:])
    logs.append('cut %s (%s)' % (rel, tag))

# ---------- LLLUiKit：旧启动/进度浮层搬到 LLLLaunchCard.m ----------
cut('ui/LLLUiKit.m', '#pragma mark - 进度浮层', 'void LLLShowHUD(NSString *text, NSTimeInterval duration)',
    'old progress/launch')

rep('ui/LLLUiKit.h',
    '/// 启动序列：标题滑入 + 滑动验证 + 初始化进度\nvoid LLLShowLaunch(void);',
    '/// 启动序列：卡片 + 圆环进度（实现见 LLLLaunchCard.m）\nvoid LLLShowLaunch(void);\n\n'
    '/// 推进启动圆环；p >= 1 自动收起\nvoid LLLLaunchSetProgress(CGFloat p, NSString * _Nullable status);',
    'launch decl')

# ---------- 主题色 / 图标 ----------
s = read('core/BaseComponents.m')
a = s.find('static UIColor *LLLThemeDefaultPreset(LLLThemeIndex i) {')
b = s.find('#pragma mark - behavior_packs / 全局清单')
if a >= 0 and b > a:
    neutral = (
        '// 主题色已移除：统一中性白\n'
        'UIColor *LLLAccentColorFor(LLLThemeIndex i) { (void)i; return [UIColor colorWithWhite:0.97 alpha:1.0]; }\n'
        'NSInteger LLLThemeIndexValue(void) { return 0; }\n'
        'void LLLSetThemeIndex(NSInteger i) { (void)i; }\n'
        'UIColor *LLLAccentColor(void) { return [UIColor colorWithWhite:0.97 alpha:1.0]; }\n'
        'NSString *LLLThemeName(LLLThemeIndex i) { (void)i; return @\"中性\"; }\n\n')
    write('core/BaseComponents.m', s[:a] + neutral + s[b:])
    logs.append('patch core/BaseComponents.m (accent)')
else:
    logs.append('skip core/BaseComponents.m (accent)')

s = read('core/BaseComponents.m')
a = s.find('// 自定义悬浮球图标')
b = s.find('NSString* docsPath(void) {')
if a >= 0 and b > a:
    icon = '''// 自定义悬浮窗图标：Documents/ 下任一文件即生效（改了自动重载）
NSString* customFloatIconPath(void) {
    NSArray *names = @[ @"bbhj_icon.png", @"bbhj_icon.jpg", @"bbhj_icon.jpeg",
                        @"float_icon.png", @"float_icon.jpg", @"悬浮图标.png" ];
    for (NSString *n in names) {
        NSString *p = [docsPath() stringByAppendingPathComponent:n];
        if ([NSFileManager.defaultManager fileExistsAtPath:p]) return p;
    }
    return nil;
}

UIImage* customFloatIcon(void) {
    static UIImage *cached;
    static NSTimeInterval cachedMtime;
    static NSString *cachedPath;

    NSString *p = customFloatIconPath();
    if (!p.length) { cached = nil; cachedPath = nil; return nil; }

    NSDictionary *attr = [NSFileManager.defaultManager attributesOfItemAtPath:p error:nil];
    if (!attr) { cached = nil; return nil; }

    NSTimeInterval mtime = [attr[NSFileModificationDate] timeIntervalSince1970];
    if (cached && mtime == cachedMtime && [cachedPath isEqualToString:p]) return cached;

    cached = [UIImage imageWithContentsOfFile:p];
    cachedMtime = mtime;
    cachedPath = p;
    return cached;
}

'''
    write('core/BaseComponents.m', s[:a] + icon + s[b:])
    logs.append('patch core/BaseComponents.m (icon)')
else:
    logs.append('skip core/BaseComponents.m (icon)')

rep('core/BaseComponents.h', 'UIImage* customFloatIcon(void);',
    'UIImage* customFloatIcon(void);\nNSString* customFloatIconPath(void);', 'icon decl')

# ---------- 主界面文案 / 岛的点击 ----------
rep('ui/MainViewController.m', '_tab6 = [self tBtn:@"音乐盒" ico:@"music.note.list"',
    '_tab6 = [self tBtn:@"音乐播放器" ico:@"music.note.list"', 'tab title')
rep('ui/MainViewController.m', '[self setHeader:@"音乐盒" sub:',
    '[self setHeader:@"音乐播放器" sub:', 'header')
rep('ui/MainViewController.m', '''    __weak typeof(self) wself = self;
    [LLLMusicIsland setTapHandler:^{
        __strong typeof(wself) ss = wself;
        if (ss) [ss togglePlayPause];
    }];''',
    '''    // 灵动岛自己处理展开/收起，这里不再抢点击
    [LLLMusicIsland setTapHandler:nil];''', 'island tap')

# ---------- Features：网易云整段搬到 LLLCloudLogin.m ----------
rep('ui/MainViewController+Features.m', '#import "LLLCloudMusic.h"',
    '#import "LLLCloudMusic.h"\n#import "LLLNowPlaying.h"\n#import "LLLCloudLogin.h"', 'imports')
cut('ui/MainViewController+Features.m', '- (void)openCloudMusic {',
    'static UITextField *gSearchField = nil;', 'openCloudMusic')
cut('ui/MainViewController+Features.m', '- (void)playCloudSong:(NSDictionary *)song {',
    '#pragma mark - 材质注入', 'playCloudSong')

rep('ui/MainViewController+Features.m', 'LLLShowList(@"我喜欢的音乐", msg, titles,',
    '[self setCloudQueue:songs];\n            LLLShowList(@"我喜欢的音乐", msg, titles,', 'queue liked')
rep('ui/MainViewController+Features.m',
    'LLLShowList([NSString stringWithFormat:@"“%@” 的结果", kw],',
    '[self setCloudQueue:songs];\n            LLLShowList([NSString stringWithFormat:@"“%@” 的结果", kw],', 'queue search')

rep('ui/MainViewController+Features.m', '''    // 顶部灵动岛胶囊
    if (self.isPlaying) {
        NSString *t = (self.currentMusicIndex >= 0 &&
                       self.currentMusicIndex < (NSInteger)self.musicNames.count)
                      ? self.musicNames[(NSUInteger)self.currentMusicIndex]
                      : (self.playerTitle.text ?: @"播放中");
        [LLLMusicIsland updateTitle:t playing:YES];
    } else {
        [LLLMusicIsland updateTitle:nil playing:NO];
    }''',
    '''    // 顶部灵动岛：本地播放也走同一套状态
    if (self.isPlaying) {
        NSString *t = (self.currentMusicIndex >= 0 &&
                       self.currentMusicIndex < (NSInteger)self.musicNames.count)
                      ? self.musicNames[(NSUInteger)self.currentMusicIndex]
                      : (self.playerTitle.text ?: @"播放中");
        LLLNowPlaying *np = [LLLNowPlaying shared];
        double dur = self.audioPlayer ? self.audioPlayer.duration : 0;
        double cur = self.audioPlayer ? self.audioPlayer.currentTime : 0;
        if (![np.title isEqualToString:t]) [np beginTrack:t artist:@"本地音乐" artwork:nil duration:dur elapsed:cur];
        else { [np updateElapsed:cur duration:dur]; [np setPlaying:YES]; }
        [LLLMusicIsland updateTitle:t playing:YES];
    } else {
        [[LLLNowPlaying shared] setPlaying:NO];
        [LLLMusicIsland updateTitle:nil playing:NO];
    }''', 'local nowplaying')

# ---------- Entry ----------
rep('Entry.m', '#import "LLLUiKit.h"',
    '#import "LLLUiKit.h"\n#import "LLLStealth.h"\n#import "LLLZip.h"', 'imports')
rep('Entry.m', '            LLLLog(@"===== LLL %@ [%s] 启动 =====", kPluginVersion, __DATE__);',
    '            LLLStealthInstall();\n\n            LLLLog(@"===== LLL %@ [%s] 启动 =====", kPluginVersion, __DATE__);',
    'stealth install')
rep('Entry.m', '''            // 实验开关：只有手动放了 LLL_PATCH_BUJI 才动手
            if (LLLFileExists(@"LLL_PATCH_BUJI")) {
                LLLLog(@"检测到 LLL_PATCH_BUJI，尝试禁用 bk_dl_req");
                LLLPatchBuji();
            }''',
    '''            // 检测规避：默认回掉 bk_dl_req；放 LLL_NO_PATCH_BUJI 可关
            if (!LLLFileExists(@"LLL_NO_PATCH_BUJI")) {
                BOOL patched = LLLStealthPatchBuji();
                LLLLog(@"STEALTH: bk_dl_req %@", patched ? @"已禁用" : @"未处理");
            }''', 'buji')

rep('Entry.m', '''                    } @catch (NSException *e) {
                        LLLLog(@"showWatermark 异常: %@", e.reason);
                    }
                });''',
    '''                    } @catch (NSException *e) {
                        LLLLog(@"showWatermark 异常: %@", e.reason);
                    }

                    // 材质包自动导入（Documents 或 Caizhi 下的 zip / mcpack）
                    dispatch_async(dispatch_get_global_queue(QOS_CLASS_UTILITY, 0), ^{
                        NSUInteger n = 0;
                        @try { n = [LLLZip importPendingArchives]; }
                        @catch (NSException *e) { LLLLog(@"ZIP 导入异常: %@", e.reason); }
                        if (n) LLLLog(@"ZIP 自动导入 %lu 个材质包", (unsigned long)n);
                        dispatch_async(dispatch_get_main_queue(), ^{
                            LLLLaunchSetProgress(1.0, n ? [NSString stringWithFormat:@"已导入 %lu 个材质包", (unsigned long)n]
                                                        : @"准备就绪");
                        });
                    });
                });''', 'zip import')

# ---------- Makefile ----------
rep('Makefile', '    overlay/FloatMonitor.m \\\n    overlay/LLLMusicIsland.m \\',
    '    overlay/FloatMonitor.m \\\n    overlay/LLLNowPlaying.m \\\n    overlay/LLLMusicIsland.m \\', 'files overlay')
rep('Makefile', '    ui/LLLCloudMusic.m \\\n    Entry.m',
    '    ui/LLLCloudMusic.m \\\n    ui/LLLCloudLogin.m \\\n    ui/LLLLaunchCard.m \\\n'
    '    core/LLLStealth.m \\\n    core/LLLZip.m \\\n    Entry.m', 'files ui')
rep('Makefile', 'bbhj_online_FRAMEWORKS = UIKit Foundation AVFoundation PhotosUI ImageIO CoreImage CoreGraphics',
    'bbhj_online_FRAMEWORKS = UIKit Foundation AVFoundation PhotosUI ImageIO CoreImage CoreGraphics Security',
    'frameworks')
rep('Makefile', 'bbhj_online_LDFLAGS = -Wl,-U,___isPlatformVersionAtLeast',
    'bbhj_online_LDFLAGS = -Wl,-U,___isPlatformVersionAtLeast -lz', 'ldflags')

# ---------- 版本 ----------
rep('core/PluginInfo.h', '#define kPluginVersion @"1.6"', '#define kPluginVersion @"2.0"', 'version')
rep('core/PluginInfo.h', '    @"• 主题色可切换（蓝/青/紫/橙/粉）", \\',
    '    @"• 中性配色：主题色已移除，统一系统白/灰", \\', 'features theme')
rep('core/PluginInfo.h', '    @"• 音乐盒（支持 mp3 / mp4 等）", \\',
    '    @"• 音乐播放器（本地 mp3/mp4 + 网易云扫码/手机号/Cookie）", \\\n'
    '    @"• 灵动岛：胶囊 / 展开态，封面 + 跑马灯 + 波形 + 进度", \\', 'features music')

for line in logs:
    print(line)
