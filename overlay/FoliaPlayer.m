//
//  FoliaPlayer.m
//  Folia 前端宿主：解包 → WKWebView(file://) → 内联自动播放
//

#import "FoliaPlayer.h"
#import "FoliaPayload.h"
#import <AVFoundation/AVFoundation.h>
#import <WebKit/WebKit.h>

static WKWebView *gWeb = nil;
static __weak UIView *gHost = nil;
static BOOL gLoading = NO;

@implementation FoliaPlayer

+ (BOOL)isLoaded { return gWeb != nil; }

+ (UIView *)viewIfLoaded { return gWeb; }

/* 游戏通常把音频会话设成 Ambient/Playback；这里明确走 Playback，
   否则静音键一开、或者游戏切走音频会话，网页里的音频就没声。 */
+ (void)activateAudioSession {
    AVAudioSession *s = AVAudioSession.sharedInstance;
    [s setCategory:AVAudioSessionCategoryPlayback error:nil];
    [s setActive:YES error:nil];
}

+ (void)loadInto:(UIView *)host completion:(void (^)(BOOL))done {
    if (!host) { if (done) done(NO); return; }
    gHost = host;

    if (gWeb) {
        gWeb.hidden = NO;
        if (gWeb.superview != host) [host addSubview:gWeb];
        if (done) done(YES);
        return;
    }
    if (gLoading) { if (done) done(YES); return; }
    gLoading = YES;

    [self activateAudioSession];

    FoliaEnsureReady(^(BOOL ok, NSString *root, NSString *err) {
        gLoading = NO;
        if (!ok || !root.length) {
            if (err.length) NSLog(@"[Folia] 解包失败: %@", err);
            if (done) done(NO);
            return;
        }
        [self buildWithRoot:root host:host];
        if (done) done(gWeb != nil);
    });
}

+ (void)buildWithRoot:(NSString *)root host:(UIView *)host {
    if (gWeb) return;

    WKWebViewConfiguration *cfg = [[WKWebViewConfiguration alloc] init];
    cfg.allowsInlineMediaPlayback = YES;
    cfg.mediaTypesRequiringUserActionForPlayback = WKAudiovisualMediaTypeNone;
    cfg.suppressesIncrementalRendering = NO;
    /* 默认持久化存储：Folia 的曲库 / 主题 / 歌词解析缓存都在 IndexedDB 里 */
    cfg.websiteDataStore = WKWebsiteDataStore.defaultDataStore;
    if (@available(iOS 14.0, *)) {
        cfg.defaultWebpagePreferences.allowsContentJavaScript = YES;
    }
    /* 不加 FoliaApp/ 前缀的 UA：那是壳模式，会去找原生播放器桥；
       嵌在游戏里没有那条桥，走网页自己的 WebAudio 才出得了声 */
    cfg.applicationNameForUserAgent = @"LLL/3.4";

    WKWebView *wv = [[WKWebView alloc] initWithFrame:host.bounds configuration:cfg];
    wv.translatesAutoresizingMaskIntoConstraints = NO;
    wv.opaque = NO;
    wv.backgroundColor = UIColor.clearColor;
    wv.scrollView.bounces = NO;
    if (@available(iOS 11.0, *)) {
        wv.scrollView.contentInsetAdjustmentBehavior = UIScrollViewContentInsetAdjustmentNever;
    }
    wv.allowsBackForwardNavigationGestures = NO;

    [host addSubview:wv];
    [NSLayoutConstraint activateConstraints:@[
        [wv.topAnchor constraintEqualToAnchor:host.topAnchor],
        [wv.leadingAnchor constraintEqualToAnchor:host.leadingAnchor],
        [wv.trailingAnchor constraintEqualToAnchor:host.trailingAnchor],
        [wv.bottomAnchor constraintEqualToAnchor:host.bottomAnchor],
    ]];
    gWeb = wv;

    NSString *index = [root stringByAppendingPathComponent:@"index.html"];
    NSURL *file = [NSURL fileURLWithPath:index];
    [wv loadFileURL:file allowingReadAccessToURL:[NSURL fileURLWithPath:root]];
    NSLog(@"[Folia] 载入 %@", index);
}

+ (void)hide {
    if (gWeb) gWeb.hidden = YES;
}

+ (void)reload {
    if (!gWeb) return;
    [self activateAudioSession];
    [gWeb reload];
}

@end
