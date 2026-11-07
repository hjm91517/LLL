#import "BaseComponents.h"
#import "LLLAnim.h"
#import <ImageIO/ImageIO.h>
#import <objc/runtime.h>
#import <AVFoundation/AVFoundation.h>

@implementation PackCell
- (instancetype)initWithStyle:(UITableViewCellStyle)s reuseIdentifier:(NSString *)r {
    if (self = [super initWithStyle:s reuseIdentifier:r]) {
        self.backgroundColor = UIColor.clearColor;
        self.selectionStyle = UITableViewCellSelectionStyleNone;

        _card = [UIView new];
        LLLCardStyle(_card, kCardCornerRadius);
        _card.translatesAutoresizingMaskIntoConstraints = NO;
        [self.contentView addSubview:_card];

        _icon = [[UIImageView alloc] init];
        _icon.contentMode = UIViewContentModeScaleAspectFill;
        _icon.layer.cornerRadius = 14;
        _icon.layer.cornerCurve = kCACornerCurveContinuous;
        _icon.layer.borderWidth = kHairline;
        _icon.layer.borderColor = [UIColor colorWithWhite:1.0 alpha:0.08].CGColor;
        _icon.clipsToBounds = YES;
        _icon.translatesAutoresizingMaskIntoConstraints = NO;
        [_card addSubview:_icon];

        _title = [UILabel new];
        _title.textColor = UIColor.whiteColor;
        _title.font = [UIFont systemFontOfSize:kCellTitleFontSize weight:UIFontWeightSemibold];
        _title.translatesAutoresizingMaskIntoConstraints = NO;
        [_card addSubview:_title];

        _sub = [UILabel new];
        _sub.textColor = kSecondaryTextColor;
        _sub.font = [UIFont systemFontOfSize:12];
        _sub.text = @"材质包文件夹";
        _sub.translatesAutoresizingMaskIntoConstraints = NO;
        [_card addSubview:_sub];

        _btn = [UIButton buttonWithType:UIButtonTypeSystem];
        if (@available(iOS 13.0, *)) {
            UIImageSymbolConfiguration *cfg =
                [UIImageSymbolConfiguration configurationWithPointSize:17 weight:UIImageSymbolWeightSemibold];
            [_btn setImage:[UIImage systemImageNamed:@"plus.circle.fill" withConfiguration:cfg]
                  forState:UIControlStateNormal];
        }
        _btn.tintColor = kAccentGreen;
        _btn.backgroundColor = [UIColor colorWithWhite:1.0 alpha:0.07];
        _btn.layer.cornerRadius = 17;
        _btn.layer.cornerCurve = kCACornerCurveContinuous;
        _btn.translatesAutoresizingMaskIntoConstraints = NO;
        [_card addSubview:_btn];

        [NSLayoutConstraint activateConstraints:@[
            [_card.leadingAnchor constraintEqualToAnchor:self.contentView.leadingAnchor constant:12],
            [_card.trailingAnchor constraintEqualToAnchor:self.contentView.trailingAnchor constant:-12],
            [_card.topAnchor constraintEqualToAnchor:self.contentView.topAnchor constant:6],
            [_card.bottomAnchor constraintEqualToAnchor:self.contentView.bottomAnchor constant:-6],

            [_icon.leadingAnchor constraintEqualToAnchor:_card.leadingAnchor constant:14],
            [_icon.centerYAnchor constraintEqualToAnchor:_card.centerYAnchor],
            [_icon.widthAnchor constraintEqualToConstant:56],
            [_icon.heightAnchor constraintEqualToConstant:56],

            [_title.leadingAnchor constraintEqualToAnchor:_icon.trailingAnchor constant:14],
            [_title.topAnchor constraintEqualToAnchor:_card.topAnchor constant:16],
            [_title.trailingAnchor constraintLessThanOrEqualToAnchor:_btn.leadingAnchor constant:-10],

            [_sub.leadingAnchor constraintEqualToAnchor:_title.leadingAnchor],
            [_sub.topAnchor constraintEqualToAnchor:_title.bottomAnchor constant:4],
            [_sub.trailingAnchor constraintEqualToAnchor:_title.trailingAnchor],

            [_btn.trailingAnchor constraintEqualToAnchor:_card.trailingAnchor constant:-14],
            [_btn.centerYAnchor constraintEqualToAnchor:_card.centerYAnchor],
            [_btn.widthAnchor constraintEqualToConstant:34],
            [_btn.heightAnchor constraintEqualToConstant:34]
        ]];
    }
    return self;
}
- (void)setHighlighted:(BOOL)highlighted animated:(BOOL)animated {
    [super setHighlighted:highlighted animated:animated];
    if (highlighted) LLLPressDown(_card); else LLLPressUp(_card);
}
@end

@implementation PluginCell
- (instancetype)initWithStyle:(UITableViewCellStyle)s reuseIdentifier:(NSString *)r {
    if (self = [super initWithStyle:s reuseIdentifier:r]) {
        self.backgroundColor = UIColor.clearColor;
        self.selectionStyle = UITableViewCellSelectionStyleNone;

        _card = [UIView new];
        LLLCardStyle(_card, kCardCornerRadius);
        _card.translatesAutoresizingMaskIntoConstraints = NO;
        [self.contentView addSubview:_card];

        _title = [UILabel new];
        _title.textColor = UIColor.whiteColor;
        _title.font = [UIFont systemFontOfSize:16 weight:UIFontWeightSemibold];
        _title.translatesAutoresizingMaskIntoConstraints = NO;
        [_card addSubview:_title];

        _btn = [UIButton buttonWithType:UIButtonTypeSystem];
        if (@available(iOS 13.0, *)) {
            UIImageSymbolConfiguration *cfg =
                [UIImageSymbolConfiguration configurationWithPointSize:17 weight:UIImageSymbolWeightSemibold];
            [_btn setImage:[UIImage systemImageNamed:@"plus.circle.fill" withConfiguration:cfg]
                  forState:UIControlStateNormal];
        }
        _btn.tintColor = kAccentGreen;
        _btn.backgroundColor = [UIColor colorWithWhite:1.0 alpha:0.07];
        _btn.layer.cornerRadius = 17;
        _btn.layer.cornerCurve = kCACornerCurveContinuous;
        _btn.translatesAutoresizingMaskIntoConstraints = NO;
        [_card addSubview:_btn];

        [NSLayoutConstraint activateConstraints:@[
            [_card.leadingAnchor constraintEqualToAnchor:self.contentView.leadingAnchor constant:12],
            [_card.trailingAnchor constraintEqualToAnchor:self.contentView.trailingAnchor constant:-12],
            [_card.topAnchor constraintEqualToAnchor:self.contentView.topAnchor constant:6],
            [_card.bottomAnchor constraintEqualToAnchor:self.contentView.bottomAnchor constant:-6],

            [_title.leadingAnchor constraintEqualToAnchor:_card.leadingAnchor constant:18],
            [_title.centerYAnchor constraintEqualToAnchor:_card.centerYAnchor],
            [_title.trailingAnchor constraintLessThanOrEqualToAnchor:_btn.leadingAnchor constant:-10],

            [_btn.trailingAnchor constraintEqualToAnchor:_card.trailingAnchor constant:-14],
            [_btn.centerYAnchor constraintEqualToAnchor:_card.centerYAnchor],
            [_btn.widthAnchor constraintEqualToConstant:34],
            [_btn.heightAnchor constraintEqualToConstant:34]
        ]];
    }
    return self;
}
- (void)setHighlighted:(BOOL)highlighted animated:(BOOL)animated {
    [super setHighlighted:highlighted animated:animated];
    if (highlighted) LLLPressDown(_card); else LLLPressUp(_card);
}
@end

@implementation QueueCell
- (instancetype)initWithStyle:(UITableViewCellStyle)s reuseIdentifier:(NSString *)r {
    if (self = [super initWithStyle:s reuseIdentifier:r]) {
        self.backgroundColor = UIColor.clearColor;
        self.selectionStyle = UITableViewCellSelectionStyleNone;

        _card = [UIView new];
        LLLCardStyle(_card, kCardCornerRadius);
        _card.translatesAutoresizingMaskIntoConstraints = NO;
        [self.contentView addSubview:_card];

        _idx = [UILabel new];
        _idx.textColor = kAccentBlue;
        _idx.font = [UIFont monospacedDigitSystemFontOfSize:13 weight:UIFontWeightBold];
        _idx.textAlignment = NSTextAlignmentCenter;
        _idx.translatesAutoresizingMaskIntoConstraints = NO;
        [_card addSubview:_idx];

        _title = [UILabel new];
        _title.textColor = UIColor.whiteColor;
        _title.font = [UIFont systemFontOfSize:15 weight:UIFontWeightMedium];
        _title.translatesAutoresizingMaskIntoConstraints = NO;
        [_card addSubview:_title];

        _drag = [[UIImageView alloc] init];
        if (@available(iOS 13.0, *))
            _drag.image = [UIImage systemImageNamed:@"line.horizontal.3"];
        _drag.tintColor = [UIColor colorWithWhite:0.4 alpha:1.0];
        _drag.translatesAutoresizingMaskIntoConstraints = NO;
        [_card addSubview:_drag];

        [NSLayoutConstraint activateConstraints:@[
            [_card.leadingAnchor constraintEqualToAnchor:self.contentView.leadingAnchor constant:12],
            [_card.trailingAnchor constraintEqualToAnchor:self.contentView.trailingAnchor constant:-12],
            [_card.topAnchor constraintEqualToAnchor:self.contentView.topAnchor constant:6],
            [_card.bottomAnchor constraintEqualToAnchor:self.contentView.bottomAnchor constant:-6],

            [_idx.leadingAnchor constraintEqualToAnchor:_card.leadingAnchor constant:16],
            [_idx.centerYAnchor constraintEqualToAnchor:_card.centerYAnchor],
            [_idx.widthAnchor constraintEqualToConstant:28],

            [_title.leadingAnchor constraintEqualToAnchor:_idx.trailingAnchor constant:12],
            [_title.centerYAnchor constraintEqualToAnchor:_card.centerYAnchor],
            [_title.trailingAnchor constraintLessThanOrEqualToAnchor:_drag.leadingAnchor constant:-10],

            [_drag.trailingAnchor constraintEqualToAnchor:_card.trailingAnchor constant:-16],
            [_drag.centerYAnchor constraintEqualToAnchor:_card.centerYAnchor],
            [_drag.widthAnchor constraintEqualToConstant:24],
            [_drag.heightAnchor constraintEqualToConstant:24]
        ]];
    }
    return self;
}
- (void)setHighlighted:(BOOL)highlighted animated:(BOOL)animated {
    [super setHighlighted:highlighted animated:animated];
    if (highlighted) LLLPressDown(_card); else LLLPressUp(_card);
}
@end

CGFloat const kIconSize = 56;
NSString * const kQueueNamesKey = @"mp_qn", * const kQueuePathsKey = @"mp_qp",
         * const kPluginQueueNamesKey = @"pl_qn", * const kPluginQueuePathsKey = @"pl_qp";

dispatch_queue_t g_fileQueue(void) {
    static dispatch_queue_t q;
    static dispatch_once_t t;
    dispatch_once(&t, ^{ q = dispatch_queue_create("cw", DISPATCH_QUEUE_SERIAL); });
    return q;
}

static UIImage* loadImg(const void *d, size_t s, UIColor *fb) {
    static NSCache *c;
    static dispatch_once_t t;
    dispatch_once(&t, ^{ c = [NSCache new]; c.countLimit = 30; });
    NSString *k = [NSString stringWithFormat:@"%p", d];
    UIImage *i = [c objectForKey:k];
    if (i) return i;
    i = [UIImage imageWithData:[NSData dataWithBytesNoCopy:(void *)d length:s freeWhenDone:NO]];
    if (!i && fb) {
        UIGraphicsBeginImageContextWithOptions(CGSizeMake(kIconSize, kIconSize), NO, 0);
        [fb setFill];
        UIRectFill(CGRectMake(0, 0, kIconSize, kIconSize));
        i = UIGraphicsGetImageFromCurrentImageContext();
        UIGraphicsEndImageContext();
    }
    if (i) [c setObject:i forKey:k];
    return i;
}

UIImage* errorImage(void) { return loadImg(cwErrorImage_data, cwErrorImage_size, UIColor.systemRedColor); }
UIImage* floatIcon(void)  { return loadImg(cwFloatIcon_data, cwFloatIcon_size, UIColor.systemBlueColor); }

NSString* docsPath(void) {
    return NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES)[0];
}

void ensureDir(NSString *p) {
    NSFileManager *fm = NSFileManager.defaultManager;
    if (![fm fileExistsAtPath:p])
        [fm createDirectoryAtPath:p withIntermediateDirectories:YES attributes:nil error:nil];
}

static NSString* mkDir(NSString *name, NSString *readme) {
    static NSMutableDictionary *cache;
    static dispatch_once_t t;
    dispatch_once(&t, ^{ cache = [NSMutableDictionary new]; });
    @synchronized(cache) {
        if (!cache[name]) {
            NSString *d = [docsPath() stringByAppendingPathComponent:name];
            ensureDir(d);
            if (readme) {
                NSString *r = [d stringByAppendingPathComponent:@"README.txt"];
                if (![NSFileManager.defaultManager fileExistsAtPath:r])
                    [readme writeToFile:r atomically:YES encoding:NSUTF8StringEncoding error:nil];
            }
            cache[name] = d;
        }
        return cache[name];
    }
}

NSString* caizhiPath(void)    { return mkDir(@"Caizhi", @"材质包文件夹放入此目录\n需 pack_icon.png 和 manifest.json"); }
NSString* mcpPluginsPath(void){ return mkDir(@"mcp_plugins", @"插件文件夹放入此目录"); }
NSString* pfPath(void)        { return mkDir(@"pf", nil); }

NSString* targetPath(void) {
    static NSString *p;
    static dispatch_once_t t;
    dispatch_once(&t, ^{
        NSFileManager *fm = NSFileManager.defaultManager;

        // 1) 手动指定优先
        NSString *override = [[NSUserDefaults standardUserDefaults] stringForKey:@"LLL.targetDir"];
        BOOL isDir = NO;
        if (override.length && [fm fileExistsAtPath:override isDirectory:&isDir] && isDir) {
            p = override;
            return;
        }

        // 2) 3.10 走自建资源包（固定目录，配合 global_resource_packs.json 注册）
        p = [resourcePacksRootPath() stringByAppendingPathComponent:@"LLL_inject"];
        ensureDir(p);
    });
    return p;
}

// 当前注入目标的名字，UI 上展示用
NSString* targetPathDisplayName(void) {
    return targetPath().lastPathComponent;
}

// 游戏根目录可能落在几个不同位置（不同版本 / 越狱容器重定向 / 沙盒迁移）
NSArray<NSString*>* candidateGameBases(void) {
    NSString *home = NSHomeDirectory();
    return @[
        [home stringByAppendingPathComponent:@"Library/games/com.netease"],
        [home stringByAppendingPathComponent:@"Library/Application Support/games/com.netease"],
        [home stringByAppendingPathComponent:@"Documents/games/com.netease"],
    ];
}

NSString* neteaseGameBasePath(void) {
    static NSString *p;
    static dispatch_once_t t;
    dispatch_once(&t, ^{
        NSFileManager *fm = NSFileManager.defaultManager;
        for (NSString *c in candidateGameBases()) {
            BOOL isDir = NO;
            if (![fm fileExistsAtPath:c isDirectory:&isDir] || !isDir) continue;
            // 必须能看到 resource_packs 或 packcache 才认定是游戏根
            if ([fm fileExistsAtPath:[c stringByAppendingPathComponent:@"resource_packs"]] ||
                [fm fileExistsAtPath:[c stringByAppendingPathComponent:@"packcache"]]) {
                p = c;
                return;
            }
        }
        p = candidateGameBases().firstObject;
    });
    return p;
}

NSString* packcacheBasePath(void) {
    return [neteaseGameBasePath() stringByAppendingPathComponent:@"packcache"];
}

// 版本目录打分："3.10_FirstPatch_2024_res_s5_texture_xxx" -> 3105000
// 3.9 = 3090000 < 3.10 = 3100000，天然按版本高低排
static NSInteger LLLVersionScore(NSString *name) {
    static NSRegularExpression *re;
    static dispatch_once_t once;
    dispatch_once(&once, ^{
        re = [NSRegularExpression regularExpressionWithPattern:@"(\\d+)\\.(\\d+)" options:0 error:nil];
    });
    if (name.length == 0) return -1;

    NSTextCheckingResult *m = [re firstMatchInString:name options:0 range:NSMakeRange(0, name.length)];
    if (!m) return -1;

    NSInteger major = [[name substringWithRange:[m rangeAtIndex:1]] integerValue];
    NSInteger minor = [[name substringWithRange:[m rangeAtIndex:2]] integerValue];

    NSInteger stage = 0;
    NSRange sr = [name rangeOfString:@"res_s" options:NSCaseInsensitiveSearch];
    if (sr.location != NSNotFound) {
        NSString *tail = [name substringFromIndex:NSMaxRange(sr)];
        NSMutableString *digits = [NSMutableString string];
        for (NSUInteger i = 0; i < tail.length; i++) {
            unichar c = [tail characterAtIndex:i];
            if (c >= '0' && c <= '9') [digits appendFormat:@"%C", c];
            else break;
        }
        stage = [digits integerValue];
    }
    return major * 1000000 + minor * 10000 + stage;
}

// 3.10 的结构：resource_packs 下不再有 "3.8_FirstPatch_2024_res_s4_texture_..."
// 这类版本目录（二进制里 "FirstPatch" 已经 0 命中）。
// 现在由 global_resource_packs.json 决定加载哪些包，所以真正的适配方式是：
//   自建一个合法资源包 → 写进 resource_packs/<名字>/ → 注册到 global_resource_packs.json
NSString* resourcePacksRootPath(void) {
    NSString *root = [neteaseGameBasePath() stringByAppendingPathComponent:@"resource_packs"];
    ensureDir(root);
    return root;
}

// 3.9 及以前的"覆盖式"补丁目录（v_ 开头的新式补丁 / *texture* 老式目录）
NSArray<NSString*>* detectLegacyPatchDirs(void) {
    NSFileManager *fm = NSFileManager.defaultManager;
    NSString *root = resourcePacksRootPath();
    NSArray<NSString*> *items = [fm contentsOfDirectoryAtPath:root error:nil];
    NSMutableArray *out = [NSMutableArray array];

    for (NSString *item in items) {
        if ([item hasPrefix:@"."]) continue;
        NSString *full = [root stringByAppendingPathComponent:item];
        BOOL isDir = NO;
        if (![fm fileExistsAtPath:full isDirectory:&isDir] || !isDir) continue;

        BOOL isPatch = [item hasPrefix:@"v_"] ||
                       [item rangeOfString:@"texture" options:NSCaseInsensitiveSearch].location != NSNotFound ||
                       [item rangeOfString:@"FirstPatch" options:NSCaseInsensitiveSearch].location != NSNotFound;
        if (isPatch && ![item isEqualToString:@"LLL_inject"]) [out addObject:full];
    }
    return out;
}

#pragma mark - 自建注入包

// 固定 UUID：每次注入都是同一个包，不会在游戏里堆出一堆重复条目
static NSString* const kLLLPackUUID    = @"f3a1c7d2-8b64-4e19-9c05-4d7a2e6b91f8";
static NSString* const kLLLModuleUUID  = @"a7c4e91b-2f38-4d6a-b5c1-8e3f9a0d7c26";

BOOL lllEnsureInjectPackManifest(void) {
    NSString *dir = targetPath();
    ensureDir(dir);

    NSString *mp = [dir stringByAppendingPathComponent:@"manifest.json"];
    if ([NSFileManager.defaultManager fileExistsAtPath:mp]) return YES;

    NSDictionary *m = @{
        @"format_version" : @2,
        @"header" : @{
            @"name" : @"LLL Inject",
            @"description" : @"LLL 材质注入包",
            @"uuid" : kLLLPackUUID,
            @"version" : @[@1, @0, @0],
            @"min_engine_version" : @[@1, @21, @0],
        },
        @"modules" : @[ @{
            @"type" : @"resources",
            @"uuid" : kLLLModuleUUID,
            @"version" : @[@1, @0, @0],
        } ],
    };
    NSData *d = [NSJSONSerialization dataWithJSONObject:m
                                                options:NSJSONWritingPrettyPrinted
                                                  error:nil];
    return d && [d writeToFile:mp atomically:YES];
}

// global_resource_packs.json 的实际位置：3.10 的 reloadUserPacks() 里
// 它和 packcache / premiumcache / ResPackDownloads 是兄弟，都在游戏根下
static NSString* globalPacksJSONPath(void) {
    NSFileManager *fm = NSFileManager.defaultManager;
    NSString *base = neteaseGameBasePath();
    NSString *a = [base stringByAppendingPathComponent:@"global_resource_packs.json"];
    if ([fm fileExistsAtPath:a]) return a;
    NSString *b = [resourcePacksRootPath() stringByAppendingPathComponent:@"global_resource_packs.json"];
    if ([fm fileExistsAtPath:b]) return b;
    return a;   // 都没有就建在根下
}

BOOL lllInjectPackRegistered(void) {
    NSString *p = globalPacksJSONPath();
    NSData *d = [NSData dataWithContentsOfFile:p];
    if (!d) return NO;
    id j = [NSJSONSerialization JSONObjectWithData:d options:0 error:nil];
    if (![j isKindOfClass:NSArray.class]) return NO;
    for (NSDictionary *e in j) {
        if ([e isKindOfClass:NSDictionary.class] &&
            [e[@"pack_id"] isEqualToString:kLLLPackUUID]) return YES;
    }
    return NO;
}

BOOL lllRegisterGlobalPack(void) {
    NSString *p = globalPacksJSONPath();
    NSMutableArray *arr = [NSMutableArray array];

    NSData *d = [NSData dataWithContentsOfFile:p];
    if (d) {
        id j = [NSJSONSerialization JSONObjectWithData:d options:0 error:nil];
        if ([j isKindOfClass:NSArray.class]) [arr addObjectsFromArray:j];
    }

    BOOL has = NO;
    for (NSDictionary *e in arr) {
        if ([e isKindOfClass:NSDictionary.class] &&
            [e[@"pack_id"] isEqualToString:kLLLPackUUID]) { has = YES; break; }
    }
    if (!has) {
        [arr addObject:@{ @"pack_id" : kLLLPackUUID, @"version" : @[@1, @0, @0] }];
    }

    NSData *out = [NSJSONSerialization dataWithJSONObject:arr
                                                  options:NSJSONWritingPrettyPrinted
                                                    error:nil];
    return out && [out writeToFile:p atomically:YES];
}

// 预留：路径缓存都是 dispatch_once，只能重启生效。保留给 UI 用。
void lllResetPathCache(void) { }


// packcache 下所有含 *.mcp 的目录 —— 3.10 换了脚本名也能认出来
NSArray<NSString*>* findAllMCPTargets(void) {
    NSFileManager *fm = NSFileManager.defaultManager;
    NSString *base = packcacheBasePath();
    NSArray<NSString*> *dirs = [fm contentsOfDirectoryAtPath:base error:nil];
    if (!dirs.count) return @[];

    NSMutableArray *out = [NSMutableArray array];
    for (NSString *d in dirs) {
        NSString *full = [base stringByAppendingPathComponent:d];
        BOOL isDir = NO;
        if (![fm fileExistsAtPath:full isDirectory:&isDir] || !isDir) continue;

        for (NSString *f in [fm contentsOfDirectoryAtPath:full error:nil]) {
            if ([f.pathExtension.lowercaseString isEqualToString:@"mcp"]) {
                [out addObject:full];
                break;
            }
        }
    }
    return out;
}

// 按关键字命中（目录名或内部文件名），命中不到返回空
static NSArray<NSString*>* mcpTargetsMatching(NSArray<NSString*> *keywords) {
    NSFileManager *fm = NSFileManager.defaultManager;
    NSMutableArray *hits = [NSMutableArray array];

    for (NSString *dir in findAllMCPTargets()) {
        NSString *name = dir.lastPathComponent;
        NSArray<NSString*> *inner = [fm contentsOfDirectoryAtPath:dir error:nil];

        BOOL matched = NO;
        for (NSString *kw in keywords) {
            if ([name rangeOfString:kw options:NSCaseInsensitiveSearch].location != NSNotFound) { matched = YES; break; }
            for (NSString *f in inner) {
                if ([f rangeOfString:kw options:NSCaseInsensitiveSearch].location != NSNotFound) { matched = YES; break; }
            }
            if (matched) break;
        }
        if (matched) [hits addObject:dir];
    }
    return hits;
}

NSString* findBugudaoTarget(void) {
    return mcpTargetsMatching(@[@"hud", @"bugudao", @"bjd", @"布吉岛"]).firstObject;
}

NSArray<NSString*>* findAllBugudaoTargets(void) {
    NSArray *r = mcpTargetsMatching(@[@"hud", @"bugudao", @"bjd", @"布吉岛"]);
    // 新版本改了脚本名的极端情况：退到全部 mcp 目录，宁可写进去也不报「目标不存在」
    return r.count ? r : findAllMCPTargets();
}

NSArray<NSString*>* findAllMisakiTargets(void) {
    NSArray *r = mcpTargetsMatching(@[@"misaki", @"msk"]);
    return r.count ? r : findAllMCPTargets();
}

NSRegularExpression* killenRegex(void) {
    static NSRegularExpression *r;
    static dispatch_once_t t;
    dispatch_once(&t, ^{
        r = [NSRegularExpression regularExpressionWithPattern:
             @"player\\.entity\\.json|fancy\\.json|sad\\.json|terrain\\.material|entity\\.material|"
             "player\\.animation_controllers\\.json|player\\.animation\\.json|"
             "stand_player\\.animation_controllers\\.root\\.v1\\.json|"
             "enchanting_screen\\.json|enchanting_screen_pocket\\.json|"
             "how_to_play_screen\\.json|hud_screen\\.json|"
             "inventory_screen\\.json|inventory_screen_pocket\\.json|"
             "netease_chat_screen\\.json|progress_screen\\.json|"
             "settings_screen\\.json|start_screen\\.json|ui_common\\.json"
             options:NSRegularExpressionCaseInsensitive error:nil];
    });
    return r;
}

void scanPacks(void(^cb)(NSString*, NSString*, BOOL)) {
    NSFileManager *fm = NSFileManager.defaultManager;
    NSString *dir = caizhiPath();
    for (NSString *item in [fm contentsOfDirectoryAtPath:dir error:nil]) {
        if ([item hasPrefix:@"."] || [item isEqualToString:@"README.txt"]) continue;
        NSString *full = [dir stringByAppendingPathComponent:item];
        NSDictionary *attr = [fm attributesOfItemAtPath:full error:nil];      // 一次 syscall 拿类型
        if (attr && [attr[NSFileType] isEqualToString:NSFileTypeDirectory]) {
            cb(item, full, [fm fileExistsAtPath:[full stringByAppendingPathComponent:@"pack_icon.png"]]);
        }
    }
}

void scanPlugins(void(^cb)(NSString*, NSString*)) {
    NSFileManager *fm = NSFileManager.defaultManager;
    for (NSString *item in [fm contentsOfDirectoryAtPath:mcpPluginsPath() error:nil]) {
        if ([item hasPrefix:@"."] || [item isEqualToString:@"README.txt"]) continue;
        NSString *sub = [mcpPluginsPath() stringByAppendingPathComponent:item];
        BOOL isDir;
        if ([fm fileExistsAtPath:sub isDirectory:&isDir] && isDir) cb(item, sub);
    }
}


// 直接按目标尺寸解码（ImageIO 缩略图），避免把 512×512 的 pack_icon 全解码再缩放
static UIImage* downsample(NSString *path, CGFloat side) {
    CGImageSourceRef src = CGImageSourceCreateWithURL((__bridge CFURLRef)[NSURL fileURLWithPath:path], NULL);
    if (!src) return nil;
    CGFloat scale = UIScreen.mainScreen.scale;
    if (scale <= 0) scale = 2.0;
    CFDictionaryRef opts = (__bridge CFDictionaryRef)@{
        (id)kCGImageSourceCreateThumbnailFromImageAlways : @YES,
        (id)kCGImageSourceCreateThumbnailWithTransform   : @YES,
        (id)kCGImageSourceThumbnailMaxPixelSize          : @(ceil(side * scale)),
        (id)kCGImageSourceShouldCacheImmediately         : @YES,
    };
    CGImageRef cg = CGImageSourceCreateThumbnailAtIndex(src, 0, opts);
    CFRelease(src);
    if (!cg) return nil;
    UIImage *img = [UIImage imageWithCGImage:cg scale:scale orientation:UIImageOrientationUp];
    CGImageRelease(cg);
    return img;
}

UIImage* cachedIcon(NSString *path, BOOL hasIcon) {
    static NSCache *c;
    static dispatch_once_t t;
    dispatch_once(&t, ^{ c = [NSCache new]; c.countLimit = 50; });
    NSString *k = [NSString stringWithFormat:@"%@_%d", path, hasIcon];
    UIImage *i = [c objectForKey:k];
    if (i) return i;
    i = hasIcon ? downsample([path stringByAppendingPathComponent:@"pack_icon.png"], kIconSize) : nil;
    if (!i) i = errorImage();
    if (i) [c setObject:i forKey:k];
    return i;
}

NSString* musicPath(void) {
    static NSString *path;
    static dispatch_once_t once;
    dispatch_once(&once, ^{
        path = [docsPath() stringByAppendingPathComponent:@"music"];
        ensureDir(path);
    });
    return path;
}

void scanMusicFiles(void(^block)(NSString *name, NSString *path)) {
    NSFileManager *fm = [NSFileManager defaultManager];
    NSArray *items = [fm contentsOfDirectoryAtPath:musicPath() error:nil];
    for (NSString *item in items) {
        if ([item hasPrefix:@"."]) continue;
        NSString *ext = item.pathExtension.lowercaseString;
        if (![ext isEqualToString:@"mp3"] && ![ext isEqualToString:@"wav"] &&
            ![ext isEqualToString:@"m4a"] && ![ext isEqualToString:@"aac"] &&
            ![ext isEqualToString:@"flac"] && ![ext isEqualToString:@"mp4"] &&
            ![ext isEqualToString:@"mov"]) continue;
        NSString *full = [musicPath() stringByAppendingPathComponent:item];
        BOOL isDir;
        if ([fm fileExistsAtPath:full isDirectory:&isDir] && !isDir) {
            block(item, full);
        }
    }
}

NSString* backgroundsDir(void) {
    NSString *dir = [docsPath() stringByAppendingPathComponent:@"backgrounds"];
    ensureDir(dir);
    return dir;
}

NSArray<NSString*>* backgroundFiles(void) {
    NSFileManager *fm = [NSFileManager defaultManager];
    NSArray *files = [fm contentsOfDirectoryAtPath:backgroundsDir() error:nil];
    NSPredicate *pred = [NSPredicate predicateWithFormat:@"(pathExtension IN %@)",
                         @[@"png", @"jpg", @"jpeg", @"mp4", @"mov"]];
    files = [files filteredArrayUsingPredicate:pred];
    files = [files sortedArrayUsingSelector:@selector(localizedStandardCompare:)];
    return files;
}

void PlayHaptic(BOOL s) {
    if (@available(iOS 10.0, *))
        [[[UINotificationFeedbackGenerator alloc] init] notificationOccurred:s ? UINotificationFeedbackTypeSuccess : UINotificationFeedbackTypeError];
}

void PlayHapticWarning(void) {
    if (@available(iOS 10.0, *))
        [[[UINotificationFeedbackGenerator alloc] init] notificationOccurred:UINotificationFeedbackTypeWarning];
}

static BaseOverlayWindow* toastWin(void) {
    static BaseOverlayWindow *w;
    static dispatch_once_t t;
    dispatch_once(&t, ^{
        if (@available(iOS 13.0, *)) {
            UIWindowScene *scene = nil;
            for (UIScene *s in UIApplication.sharedApplication.connectedScenes) {
                if ([s isKindOfClass:[UIWindowScene class]] &&
                    s.activationState == UISceneActivationStateForegroundActive) {
                    scene = (UIWindowScene *)s;
                    break;
                }
            }
            // iOS13+ 必须绑 windowScene，否则 window 不上屏
            w = scene ? [[BaseOverlayWindow alloc] initWithWindowScene:scene]
                      : [[BaseOverlayWindow alloc] initWithFrame:UIScreen.mainScreen.bounds];
        } else {
            w = [[BaseOverlayWindow alloc] initWithFrame:UIScreen.mainScreen.bounds];
        }
        w.windowLevel = UIWindowLevelAlert + 10;
        w.userInteractionEnabled = NO;
        w.rootViewController = [UIViewController new];
        w.hidden = NO;
    });
    return w;
}

static NSMutableArray<UIView*>* toastArr(void) {
    static NSMutableArray *a;
    static dispatch_once_t t;
    dispatch_once(&t, ^{ a = [NSMutableArray new]; });
    return a;
}

static CGFloat tSpace = 10, tMargin = 16, tBottom = 24;

static void layoutToasts(BOOL anim) {
    NSArray *ts = [toastArr() copy];
    if (!ts.count) return;
    UIWindow *w = toastWin();
    CGFloat bo = tBottom;
    if (@available(iOS 11.0, *))
        bo += w.safeAreaInsets.bottom;
    __block CGFloat y = w.bounds.size.height - bo;
    for (UIView *v in [ts reverseObjectEnumerator]) {
        CGRect f = v.frame;
        f.origin.y = y - f.size.height;
        y = f.origin.y - tSpace;
        if (anim) {
            [UIView animateWithDuration:0.35 delay:0 usingSpringWithDamping:0.8 initialSpringVelocity:0.2 options:0 animations:^{ v.frame = f; } completion:nil];
        } else {
            v.frame = f;
        }
    }
}

void ShowToast(NSString *msg, NSTimeInterval dur, BOOL br, BOOL err) {
    dispatch_async(dispatch_get_main_queue(), ^{
        UIWindow *w = toastWin();
        w.hidden = NO;

        UIView *c = [UIView new];
        c.backgroundColor = err ? [UIColor colorWithRed:0.85 green:0.2 blue:0.2 alpha:0.95] : [UIColor colorWithWhite:0.15 alpha:0.95];
        c.layer.cornerRadius = 12;
        c.clipsToBounds = YES;
        c.alpha = 0;

        UIImageView *iv = [[UIImageView alloc] initWithFrame:CGRectMake(12, 10, 18, 18)];
        if (@available(iOS 13.0, *)) {
            iv.image = [UIImage systemImageNamed:err ? @"xmark.circle.fill" : @"checkmark.circle.fill"];
            iv.tintColor = UIColor.whiteColor;
        }
        [c addSubview:iv];

        UILabel *l = [UILabel new];
        l.text = msg;
        l.textColor = UIColor.whiteColor;
        l.font = [UIFont systemFontOfSize:14 weight:UIFontWeightMedium];
        l.numberOfLines = 0;
        l.textAlignment = NSTextAlignmentLeft;
        [c addSubview:l];

        CGFloat mw = br ? MIN(220, w.bounds.size.width - 48) : w.bounds.size.width - 48;
        CGSize sz = [l sizeThatFits:CGSizeMake(mw - 50, CGFLOAT_MAX)];
        l.frame = CGRectMake(38, 10, sz.width, sz.height);

        CGFloat ww = sz.width + 52, hh = MAX(sz.height + 20, 38);
        c.frame = CGRectMake(br ? w.bounds.size.width - ww - tMargin : (w.bounds.size.width - ww) / 2,
                             w.bounds.size.height, ww, hh);

        [w addSubview:c];
        [toastArr() addObject:c];
        layoutToasts(NO);

        [UIView animateWithDuration:0.4 delay:0 usingSpringWithDamping:0.8 initialSpringVelocity:0.3 options:0 animations:^{
            c.alpha = 1;
        } completion:^(BOOL finished) {
            dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(dur * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
                [UIView animateWithDuration:0.25 animations:^{
                    c.alpha = 0;
                    c.transform = CGAffineTransformMakeScale(0.9, 0.9);
                } completion:^(BOOL finished) {
                    [c removeFromSuperview];
                    [toastArr() removeObject:c];
                    layoutToasts(YES);
                }];
            });
        }];
    });
}

static MaterialHUD *g_hud;
@implementation MaterialHUD {
    UIActivityIndicatorView *_s;
    UILabel *_l;
}

+ (void)show:(NSString *)t inView:(UIView *)v {
    [self dismiss];
    g_hud = [[MaterialHUD alloc] initWithFrame:v.bounds text:t];
    g_hud.alpha = 0;
    [v addSubview:g_hud];
    [UIView animateWithDuration:0.2 animations:^{ g_hud.alpha = 1; }];
}

+ (void)dismiss {
    if (!g_hud) return;
    [UIView animateWithDuration:0.2 animations:^{ g_hud.alpha = 0; } completion:^(BOOL finished) {
        [g_hud removeFromSuperview];
        g_hud = nil;
    }];
}

- (instancetype)initWithFrame:(CGRect)f text:(NSString *)t {
    if (self = [super initWithFrame:f]) {
        self.backgroundColor = kHUDOverlayColor;

        UIView *box = [UIView new];
        box.backgroundColor = [UIColor colorWithWhite:0.15 alpha:0.95];
        box.layer.cornerRadius = 18;
        box.clipsToBounds = YES;
        box.translatesAutoresizingMaskIntoConstraints = NO;
        [self addSubview:box];

        _s = [[UIActivityIndicatorView alloc] initWithActivityIndicatorStyle:UIActivityIndicatorViewStyleLarge];
        _s.color = UIColor.whiteColor;
        _s.translatesAutoresizingMaskIntoConstraints = NO;
        [_s startAnimating];
        [box addSubview:_s];

        _l = [UILabel new];
        _l.text = t;
        _l.textColor = UIColor.whiteColor;
        _l.font = [UIFont systemFontOfSize:15 weight:UIFontWeightMedium];
        _l.translatesAutoresizingMaskIntoConstraints = NO;
        [box addSubview:_l];

        [NSLayoutConstraint activateConstraints:@[
            [box.centerXAnchor constraintEqualToAnchor:self.centerXAnchor],
            [box.centerYAnchor constraintEqualToAnchor:self.centerYAnchor],
            [box.widthAnchor constraintGreaterThanOrEqualToConstant:120],
            [box.heightAnchor constraintGreaterThanOrEqualToConstant:100],
            [_s.topAnchor constraintEqualToAnchor:box.topAnchor constant:24],
            [_s.centerXAnchor constraintEqualToAnchor:box.centerXAnchor],
            [_l.topAnchor constraintEqualToAnchor:_s.bottomAnchor constant:14],
            [_l.leadingAnchor constraintEqualToAnchor:box.leadingAnchor constant:20],
            [_l.trailingAnchor constraintEqualToAnchor:box.trailingAnchor constant:-20],
            [_l.bottomAnchor constraintEqualToAnchor:box.bottomAnchor constant:-20]
        ]];
    }
    return self;
}
@end

@implementation BaseOverlayWindow
- (instancetype)initWithFrame:(CGRect)frame {
    self = [super initWithFrame:frame];
    if (self) {
        if (@available(iOS 13.0, *)) {
            self.overrideUserInterfaceStyle = UIUserInterfaceStyleDark;
        }
    }
    return self;
}
- (instancetype)initWithWindowScene:(UIWindowScene *)windowScene API_AVAILABLE(ios(13.0)) {
    self = [super initWithWindowScene:windowScene];
    if (self) {
        if (@available(iOS 13.0, *)) {
            self.overrideUserInterfaceStyle = UIUserInterfaceStyleDark;
        }
    }
    return self;
}
@end

@interface WatermarkWindow : BaseOverlayWindow @end
@implementation WatermarkWindow
- (UIView *)hitTest:(CGPoint)point withEvent:(UIEvent *)event {
    UIView *hit = [super hitTest:point withEvent:event];
    if (hit == self || hit == self.rootViewController.view) return nil;
    return hit;
}
@end

@interface WatermarkView : UIView
@property (nonatomic, strong) CAGradientLayer *gradientLayer;
@property (nonatomic, strong) CATextLayer *textLayer;
- (void)handleTap;
@end

@implementation WatermarkView

- (instancetype)initWithFrame:(CGRect)frame {
    if (self = [super initWithFrame:frame]) {
        self.backgroundColor = [UIColor colorWithWhite:0.08 alpha:0.75];
        self.layer.cornerRadius = 12;
        self.layer.masksToBounds = YES;
        self.layer.borderColor = [UIColor colorWithWhite:1.0 alpha:0.15].CGColor;
        self.layer.borderWidth = 0.5;

        _gradientLayer = [CAGradientLayer layer];
        _gradientLayer.colors = @[
            (id)[UIColor systemRedColor].CGColor,
            (id)[UIColor systemOrangeColor].CGColor,
            (id)[UIColor systemYellowColor].CGColor,
            (id)[UIColor systemGreenColor].CGColor,
            (id)[UIColor systemBlueColor].CGColor,
            (id)[UIColor systemPurpleColor].CGColor
        ];
        _gradientLayer.startPoint = CGPointMake(0, 0.5);
        _gradientLayer.endPoint = CGPointMake(1, 0.5);
        [self.layer addSublayer:_gradientLayer];

        _textLayer = [CATextLayer layer];
        _textLayer.string = @"云落制作 QQ群:1071596112";
        _textLayer.fontSize = 14;
        _textLayer.alignmentMode = kCAAlignmentCenter;
        _textLayer.foregroundColor = [UIColor whiteColor].CGColor;
        _textLayer.contentsScale = [UIScreen mainScreen].scale;
        _gradientLayer.mask = _textLayer;

        UITapGestureRecognizer *tap = [[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(handleTap)];
        [self addGestureRecognizer:tap];
    }
    return self;
}

- (void)layoutSubviews {
    [super layoutSubviews];
    self.gradientLayer.frame = self.bounds;
    CGFloat insetX = 12;
    CGFloat insetY = 6;
    self.textLayer.frame = CGRectInset(self.bounds, insetX, insetY);
}

- (void)handleTap {
    NSString *groupID = @"1071596112";
    NSURL *url1 = [NSURL URLWithString:[NSString stringWithFormat:@"mqqapi://card/show_pslcard?src_type=internal&version=1&card_type=group&uin=%@", groupID]];
    NSURL *url2 = [NSURL URLWithString:[NSString stringWithFormat:@"mqqapi://group/invite_card?id=%@", groupID]];
    UIApplication *app = [UIApplication sharedApplication];
    if ([app canOpenURL:url1]) {
        [app openURL:url1 options:@{} completionHandler:nil];
    } else if ([app canOpenURL:url2]) {
        [app openURL:url2 options:@{} completionHandler:nil];
    } else {
        UIAlertController *alert = [UIAlertController alertControllerWithTitle:@"提示"
                                                                       message:@"请手动搜索QQ群：1071596112 加入"
                                                                preferredStyle:UIAlertControllerStyleAlert];
        [alert addAction:[UIAlertAction actionWithTitle:@"好的" style:UIAlertActionStyleDefault handler:nil]];
        UIWindow *currentWindow = self.window;
        if (currentWindow) {
            [currentWindow.rootViewController presentViewController:alert animated:YES completion:nil];
        }
    }
}
@end

static WatermarkWindow *watermarkWin = nil;

static BOOL watermarkEnabled(void) {
    NSNumber *val = [[NSUserDefaults standardUserDefaults] objectForKey:@"WatermarkEnabled"];
    return val ? val.boolValue : YES;
}

void showWatermark(void) {
    if (!watermarkEnabled()) {
        hideWatermark();
        return;
    }
    if (watermarkWin) return;

    UIWindowScene *scene = nil;
    if (@available(iOS 13.0, *)) {
        for (UIScene *s in UIApplication.sharedApplication.connectedScenes) {
            if ([s isKindOfClass:[UIWindowScene class]] && ((UIWindowScene *)s).activationState == UISceneActivationStateForegroundActive) {
                scene = (UIWindowScene *)s;
                break;
            }
        }
    }

    CGRect screen = UIScreen.mainScreen.bounds;
    watermarkWin = scene ? [[WatermarkWindow alloc] initWithWindowScene:scene]
                         : [[WatermarkWindow alloc] initWithFrame:screen];
    watermarkWin.windowLevel = UIWindowLevelStatusBar + 200;
    watermarkWin.backgroundColor = [UIColor clearColor];
    watermarkWin.userInteractionEnabled = YES;
    watermarkWin.rootViewController = [UIViewController new];

    NSString *text = @"云落制作 QQ群:1071596112";
    UIFont *wmFont = [UIFont systemFontOfSize:14 weight:UIFontWeightSemibold];
    CGSize textSize = [text sizeWithAttributes:@{NSFontAttributeName: wmFont}];
    CGFloat width = textSize.width + 32;
    CGFloat height = textSize.height + 20;

    // 窗口刚建出来时 safeAreaInsets 还是 0，得从状态栏拿真实顶部安全区
    CGFloat topInset = 8;
    if (@available(iOS 13.0, *)) {
        if (scene.statusBarManager) {
            topInset = MAX(8, CGRectGetHeight(scene.statusBarManager.statusBarFrame));
        }
    } else {
        topInset = MAX(8, UIApplication.sharedApplication.statusBarFrame.size.height);
    }

    CGFloat x = screen.size.width - width - 12;
    CGFloat y = topInset + 6;
    watermarkWin.frame = CGRectMake(x, y, width, height);

    WatermarkView *wm = [[WatermarkView alloc] initWithFrame:watermarkWin.bounds];
    [watermarkWin.rootViewController.view addSubview:wm];
    watermarkWin.hidden = NO;
}

void hideWatermark(void) {
    if (watermarkWin) {
        watermarkWin.hidden = YES;
        watermarkWin = nil;
    }
}

void setWatermarkEnabled(BOOL enabled) {
    [[NSUserDefaults standardUserDefaults] setBool:enabled forKey:@"WatermarkEnabled"];
    if (enabled) {
        showWatermark();
    } else {
        hideWatermark();
    }
}

BOOL isWatermarkEnabled(void) {
    return watermarkEnabled();
}
