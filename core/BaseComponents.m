#import "BaseComponents.h"
#import "LLLAnim.h"
#import <ImageIO/ImageIO.h>
#import <CommonCrypto/CommonCrypto.h>
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

// 固定 UUID：每次注入都是同一个包，不会在游戏里堆出一堆重复条目
static NSString* const kLLLPackUUID    = @"f3a1c7d2-8b64-4e19-9c05-4d7a2e6b91f8";
static NSString* const kLLLModuleUUID  = @"a7c4e91b-2f38-4d6a-b5c1-8e3f9a0d7c26";

NSString* targetPath(void) {
    static NSString *p;
    static dispatch_once_t t;
    dispatch_once(&t, ^{
        NSFileManager *fm = NSFileManager.defaultManager;

        NSString *override = [[NSUserDefaults standardUserDefaults] stringForKey:@"LLL.targetDir"];
        BOOL isDir = NO;
        if (override.length && [fm fileExistsAtPath:override isDirectory:&isDir] && isDir) {
            p = override;
            return;
        }

        // 3.10 的包目录按 "<uuid>_resource_packs_<名字>" 命名（游戏自己的包就是这个格式）。
        // 裸名字 LLL_inject 会被扫描器直接跳过 —— 这就是上一版文件全写了但游戏不认的原因。
        p = [resourcePacksRootPath() stringByAppendingPathComponent:lllPackDirName()];
        ensureDir(p);

        // 迁移：清掉旧版留下的裸目录
        NSString *legacy = [resourcePacksRootPath() stringByAppendingPathComponent:@"LLL_inject"];
        if ([fm fileExistsAtPath:legacy]) [fm removeItemAtPath:legacy error:nil];
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



#pragma mark - 公共日志

void lllLog(NSString *fmt, ...) {
    @try {
        va_list ap; va_start(ap, fmt);
        NSString *body = [[NSString alloc] initWithFormat:fmt arguments:ap];
        va_end(ap);

        NSDateFormatter *df = [NSDateFormatter new];
        df.dateFormat = @"HH:mm:ss.SSS";
        NSString *line = [NSString stringWithFormat:@"[%@] %@\n",
                          [df stringFromDate:[NSDate date]], body];

        NSString *docs = NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES).firstObject;
        if (!docs.length) return;
        NSString *p = [docs stringByAppendingPathComponent:@"LLL_runtime.log"];

        NSFileHandle *fh = [NSFileHandle fileHandleForWritingAtPath:p];
        if (!fh) {
            [line writeToFile:p atomically:YES encoding:NSUTF8StringEncoding error:nil];
            return;
        }
        [fh seekToEndOfFile];
        [fh writeData:[line dataUsingEncoding:NSUTF8StringEncoding]];
        [fh closeFile];
    } @catch (__unused NSException *e) { }
}

#pragma mark - 注入目标枚举

// 3.10 里 reloadUserPacks() 旁边是 development_resource_packs，
// 那是 Bedrock 的「开发包」目录 —— 放进去不用注册也会被扫到。
// 所以这里把所有可能的位置都铺一遍，谁被加载算谁的。
NSArray<NSString*>* injectionTargetDirs(void) {
    NSFileManager *fm = NSFileManager.defaultManager;
    NSMutableArray *out = [NSMutableArray array];
    NSString *leaf = targetPath().lastPathComponent;

    void (^addDir)(NSString *) = ^(NSString *path) {
        if (!path.length) return;
        if ([out containsObject:path]) return;
        [out addObject:path];
    };

    addDir(targetPath());

    for (NSString *base in candidateGameBases()) {
        BOOL isDir = NO;
        if (![fm fileExistsAtPath:base isDirectory:&isDir] || !isDir) continue;

        NSString *dev = [base stringByAppendingPathComponent:@"development_resource_packs"];
        BOOL devDir = NO;
        if ([fm fileExistsAtPath:dev isDirectory:&devDir] && devDir) {
            addDir([dev stringByAppendingPathComponent:leaf]);
        }

        NSString *rp = [base stringByAppendingPathComponent:@"resource_packs"];
        BOOL rpDir = NO;
        if ([fm fileExistsAtPath:rp isDirectory:&rpDir] && rpDir) {
            addDir([rp stringByAppendingPathComponent:leaf]);
        }
    }

    // 游戏自己那几个 3.10_v_* 热更包，直接覆盖进去
    for (NSString *dir in hotPatchPackDirs()) addDir(dir);

    // 用户自己下载的包 —— 最后一层，游戏一般不对它做完整性校验
    for (NSString *dir in userResourcePackDirs()) addDir(dir);

    return out;
}

// 把游戏根下一层的目录结构完整打进日志 —— 这是唯一能确认 3.10 真实布局的办法
static void LLLLogChildren(NSString *path, int depth, NSString *indent) {
    if (depth <= 0) return;
    NSFileManager *fm = NSFileManager.defaultManager;
    NSArray<NSString*> *items =
        [[fm contentsOfDirectoryAtPath:path error:nil] sortedArrayUsingSelector:@selector(compare:)];
    for (NSString *it in items) {
        if ([it hasPrefix:@"."]) continue;
        NSString *full = [path stringByAppendingPathComponent:it];
        BOOL d = NO;
        [fm fileExistsAtPath:full isDirectory:&d];
        if (d) {
            NSUInteger n = [fm contentsOfDirectoryAtPath:full error:nil].count;
            lllLog(@"%@  - %@/  (%lu)", indent, it, (unsigned long)n);
            if (depth > 1) LLLLogChildren(full, depth - 1, [indent stringByAppendingString:@"      "]);
        }
    }
}

void lllLogDirectorySnapshot(void) {
    NSFileManager *fm = NSFileManager.defaultManager;
    for (NSString *base in candidateGameBases()) {
        BOOL isDir = NO;
        if (![fm fileExistsAtPath:base isDirectory:&isDir] || !isDir) continue;

        lllLog(@"### BASE %@", base);
        NSArray<NSString*> *items =
            [[fm contentsOfDirectoryAtPath:base error:nil] sortedArrayUsingSelector:@selector(compare:)];
        for (NSString *it in items) {
            NSString *full = [base stringByAppendingPathComponent:it];
            BOOL d = NO;
            [fm fileExistsAtPath:full isDirectory:&d];
            if (!d) {
                lllLog(@"    [F] %@", it);
                continue;
            }
            NSUInteger n = [fm contentsOfDirectoryAtPath:full error:nil].count;
            lllLog(@"    [D] %@  (%lu)", it, (unsigned long)n);

            // 这几个目录看两层，其它只看一层
            BOOL deep = [it isEqualToString:@"resource_packs"] ||
                        [it isEqualToString:@"development_resource_packs"] ||
                        [it isEqualToString:@"behavior_packs"] ||
                        [it isEqualToString:@"packcache"] ||
                        [it isEqualToString:@"storge"] ||
                        [it isEqualToString:@"minecraftpe"];
            if (deep) LLLLogChildren(full, 2, @"        ");
        }
    }
}



// 从 resource_packs 里任意一个 "3.10_v_xxx" 目录反推版本前缀
static NSString *LLLGameVersionPrefix(void) {
    static NSString *prefix;
    static dispatch_once_t once;
    dispatch_once(&once, ^{
        prefix = @"3.10";
        NSFileManager *fm = NSFileManager.defaultManager;
        NSArray *items = [fm contentsOfDirectoryAtPath:resourcePacksRootPath() error:nil];
        NSRegularExpression *re =
            [NSRegularExpression regularExpressionWithPattern:@"^(\\d+\\.\\d+)_v_" options:0 error:nil];
        for (NSString *it in items) {
            NSTextCheckingResult *m = [re firstMatchInString:it options:0 range:NSMakeRange(0, it.length)];
            if (m) { prefix = [it substringWithRange:[m rangeAtIndex:1]]; break; }
        }
    });
    return prefix;
}

NSString* lllPackDirName(void) {
    return [NSString stringWithFormat:@"%@_v_LLL_%@_0_0_1",
            LLLGameVersionPrefix(), kLLLPackUUID];
}

// 游戏自己的 "3.10_v_*" 热更补丁包 —— 这些是肯定会被加载的
NSArray<NSString*>* hotPatchPackDirs(void) {
    NSFileManager *fm = NSFileManager.defaultManager;
    NSString *root = resourcePacksRootPath();
    NSArray<NSString*> *items = [fm contentsOfDirectoryAtPath:root error:nil];
    NSMutableArray *out = [NSMutableArray array];
    NSString *mine = lllPackDirName();

    for (NSString *it in items) {
        if ([it hasPrefix:@"."]) continue;
        if ([it isEqualToString:mine]) continue;
        if ([it rangeOfString:@"_v_"].location == NSNotFound) continue;   // 只要 3.10_v_* 这类

        NSString *full = [root stringByAppendingPathComponent:it];
        BOOL isDir = NO;
        if (![fm fileExistsAtPath:full isDirectory:&isDir] || !isDir) continue;

        // 只看名字，不看内容 —— 目录被清空过也要继续认它
        [out addObject:full];
    }
    return out;
}


// 3.10 的补丁包带 signatures.json，改动任意文件都会哈希不匹配 → 整包被判无效。
// 删掉签名文件，游戏会当成"本地未签名包"处理，通常仍然加载。
BOOL lllStripSignatures(NSString *dir) {
    NSFileManager *fm = NSFileManager.defaultManager;
    BOOL removed = NO;
    for (NSString *name in @[@"signatures.json", @"signature.json"]) {
        NSString *p = [dir stringByAppendingPathComponent:name];
        if ([fm fileExistsAtPath:p]) {
            if ([fm removeItemAtPath:p error:nil]) {
                lllLog(@"   签名文件已移除: %@/%@", dir.lastPathComponent, name);
                removed = YES;
            }
        }
    }
    return removed;
}

// 打印目标包根目录下的文件（不看子目录），一眼能看出有没有 manifest / signatures
void lllLogPackRootFiles(NSString *dir) {
    NSFileManager *fm = NSFileManager.defaultManager;
    NSArray *items = [[fm contentsOfDirectoryAtPath:dir error:nil]
                      sortedArrayUsingSelector:@selector(compare:)];
    NSMutableArray *files = [NSMutableArray array];
    for (NSString *it in items) {
        BOOL d = NO;
        [fm fileExistsAtPath:[dir stringByAppendingPathComponent:it] isDirectory:&d];
        if (!d) [files addObject:it];
    }
    lllLog(@"   [%@] 根文件: %@", dir.lastPathComponent,
           files.count ? [files componentsJoinedByString:@", "] : @"(无)");
}


#pragma mark - folder_md5.json 重写

static NSString *LLLMD5OfFile(NSString *path, BOOL uppercase) {
    // 千万别用 NSDataReadingMappedIfSafe —— 游戏在跑的时候映射它的文件，
    // 页面一被替换就 SIGBUS，那是杀不掉的崩溃。老老实实读进内存。
    NSDictionary *attr = [NSFileManager.defaultManager attributesOfItemAtPath:path error:nil];
    if (attr) {
        unsigned long long size = [attr[NSFileSize] unsignedLongLongValue];
        if (size > 8ULL * 1024 * 1024) return nil;     // 超大文件跳过，别把内存撑爆
    }
    NSData *d = [NSData dataWithContentsOfFile:path options:0 error:nil];
    if (!d) return nil;
    unsigned char digest[CC_MD5_DIGEST_LENGTH];
    CC_MD5(d.bytes, (CC_LONG)d.length, digest);
    NSMutableString *s = [NSMutableString stringWithCapacity:32];
    for (int i = 0; i < CC_MD5_DIGEST_LENGTH; i++) {
        [s appendFormat:(uppercase ? @"%02X" : @"%02x"), digest[i]];
    }
    return s;
}

// 3.10 的补丁包靠 folder_md5.json 里的哈希清单做完整性校验。
// 加了文件不改清单 → 整包判无效。这里按现存文件重算一遍。
BOOL lllRewriteFolderMD5(NSString *dir) {
    NSFileManager *fm = NSFileManager.defaultManager;
    NSString *p = [dir stringByAppendingPathComponent:@"folder_md5.json"];
    NSData *data = [NSData dataWithContentsOfFile:p];
    if (!data) return NO;

    NSString *head = [[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding];
    lllLog(@"   folder_md5 样例: %@", head.length > 200 ? [head substringToIndex:200] : head);

    id json = [NSJSONSerialization JSONObjectWithData:data options:0 error:nil];
    if (![json isKindOfClass:NSDictionary.class]) {
        lllLog(@"   folder_md5 不是字典，跳过重写");
        return NO;
    }

    // 原始文件用大写还是小写？照抄，别自作主张
    BOOL upper = NO;
    for (id v in [(NSDictionary *)json allValues]) {
        if ([v isKindOfClass:NSString.class] && [v length] == 32) {
            NSString *first = [v substringToIndex:1];
            upper = [first isEqualToString:[first uppercaseString]];
            break;
        }
    }

    NSMutableDictionary *out = [NSMutableDictionary dictionary];
    NSDirectoryEnumerator *e = [fm enumeratorAtPath:dir];
    for (NSString *rel in e) {
        if ([rel.lastPathComponent isEqualToString:@"folder_md5.json"]) continue;
        NSString *full = [dir stringByAppendingPathComponent:rel];
        BOOL isDir = NO;
        if ([fm fileExistsAtPath:full isDirectory:&isDir] && isDir) continue;
        NSString *md5 = LLLMD5OfFile(full, upper);
        if (md5) out[rel] = md5;
    }

    NSData *o = [NSJSONSerialization dataWithJSONObject:out options:0 error:nil];
    BOOL ok = o && [o writeToFile:p atomically:YES];
    lllLog(@"   folder_md5 重写: %@ (%lu 项)", ok ? @"OK" : @"FAIL", (unsigned long)out.count);
    return ok;
}

#pragma mark - 主题色

static UIColor *LLLThemeDefaultPreset(LLLThemeIndex i) {
    switch (i) {
        case LLLThemeGreen:  return [UIColor colorWithRed:0.16 green:0.82 blue:0.45 alpha:1.0];
        case LLLThemePurple: return [UIColor colorWithRed:0.62 green:0.40 blue:1.00 alpha:1.0];
        case LLLThemeOrange: return [UIColor colorWithRed:0.95 green:0.52 blue:0.12 alpha:1.0];
        case LLLThemePink:   return [UIColor colorWithRed:1.00 green:0.36 blue:0.62 alpha:1.0];
        case LLLThemeBlue:
        default:             return [UIColor colorWithRed:0.22 green:0.60 blue:1.00 alpha:1.0];
    }
}

UIColor *LLLAccentColorFor(LLLThemeIndex i) {
    if (i < 0 || i >= LLLThemeCount) i = LLLThemeBlue;
    return LLLThemeDefaultPreset(i);
}

NSInteger LLLThemeIndexValue(void) {
    NSInteger v = [[NSUserDefaults standardUserDefaults] integerForKey:@"LLL.theme"];
    if (v < 0 || v >= LLLThemeCount) v = LLLThemeBlue;
    return v;
}

void LLLSetThemeIndex(NSInteger i) {
    if (i < 0 || i >= LLLThemeCount) i = LLLThemeBlue;
    [[NSUserDefaults standardUserDefaults] setInteger:i forKey:@"LLL.theme"];
}

UIColor *LLLAccentColor(void) {
    return LLLAccentColorFor((LLLThemeIndex)LLLThemeIndexValue());
}

NSString *LLLThemeName(LLLThemeIndex i) {
    switch (i) {
        case LLLThemeGreen:  return @"\u9752";
        case LLLThemePurple: return @"\u7d2b";
        case LLLThemeOrange: return @"\u6a59";
        case LLLThemePink:   return @"\u7c89";
        default:             return @"\u84dd";
    }
}

#pragma mark - behavior_packs / 全局清单

NSArray<NSString*>* behaviorPacksDirs(void) {
    NSFileManager *fm = NSFileManager.defaultManager;
    NSString *base = [neteaseGameBasePath() stringByAppendingPathComponent:@"behavior_packs"];
    NSArray<NSString*> *items = [fm contentsOfDirectoryAtPath:base error:nil];
    NSMutableArray *out = [NSMutableArray array];
    for (NSString *d in items) {
        if ([d hasPrefix:@"."]) continue;
        NSString *full = [base stringByAppendingPathComponent:d];
        BOOL isDir = NO;
        if ([fm fileExistsAtPath:full isDirectory:&isDir] && isDir) [out addObject:full];
    }
    return out;
}

NSArray<NSString*>* globalPackJSONCandidates(void) {
    NSString *base = neteaseGameBasePath();
    return @[
        [base stringByAppendingPathComponent:@"global_resource_packs.json"],
        [base stringByAppendingPathComponent:@"resource_packs/global_resource_packs.json"],
        [base stringByAppendingPathComponent:@"minecraftpe/global_resource_packs.json"],
        [[NSHomeDirectory() stringByAppendingPathComponent:@"Documents/games/com.netease"]
            stringByAppendingPathComponent:@"global_resource_packs.json"],
    ];
}

NSArray<NSString*>* legacyPatchDirs(void) {
    return detectLegacyPatchDirs();
}

// 用户自己下载/导入的资源包（不带 _v_ 但有 pack_manifest.json）
// 这是唯一还没试过的一层：游戏把它当"用户内容"，通常不做服务端校验。
NSArray<NSString*>* userResourcePackDirs(void) {
    NSFileManager *fm = NSFileManager.defaultManager;
    NSString *root = resourcePacksRootPath();
    NSArray<NSString*> *items = [fm contentsOfDirectoryAtPath:root error:nil];
    NSMutableArray *out = [NSMutableArray array];
    NSString *mine = lllPackDirName();

    for (NSString *it in items) {
        if ([it hasPrefix:@"."]) continue;
        if ([it isEqualToString:mine]) continue;
        if ([it rangeOfString:@"_v_"].location != NSNotFound) continue;
        if ([it hasPrefix:@"vanilla"]) continue;

        NSString *full = [root stringByAppendingPathComponent:it];
        BOOL isDir = NO;
        if (![fm fileExistsAtPath:full isDirectory:&isDir] || !isDir) continue;
        // 同样只看名字，别因为被清空过就漏掉
        [out addObject:full];
    }
    return out;
}

BOOL lllEnsurePackManifestAt(NSString *dir) {
    if (!dir.length) return NO;
    ensureDir(dir);

    NSString *mp = [dir stringByAppendingPathComponent:@"manifest.json"];
    NSString *pmp = [dir stringByAppendingPathComponent:@"pack_manifest.json"];
    if ([NSFileManager.defaultManager fileExistsAtPath:mp]) {
        // 老包可能只有 manifest.json，补一份网易习惯的 pack_manifest.json
        if (![NSFileManager.defaultManager fileExistsAtPath:pmp]) {
            [[NSFileManager defaultManager] copyItemAtPath:mp toPath:pmp error:nil];
        }
        return YES;
    }

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
        @"capabilities" : @[ @"pbr" ],
    };
    NSData *d = [NSJSONSerialization dataWithJSONObject:m
                                                options:NSJSONWritingPrettyPrinted
                                                  error:nil];
    if (!d) return NO;
    BOOL ok = [d writeToFile:mp atomically:YES];
    [d writeToFile:pmp atomically:YES];
    return ok;
}

BOOL lllEnsureInjectPackManifest(void) {
    return lllEnsurePackManifestAt(targetPath());
}
BOOL lllInjectPackRegistered(void) {
    for (NSString *p in globalPackJSONCandidates()) {
        NSData *d = [NSData dataWithContentsOfFile:p];
        if (!d) continue;
        id j = [NSJSONSerialization JSONObjectWithData:d options:0 error:nil];
        if (![j isKindOfClass:NSArray.class]) continue;
        for (NSDictionary *e in j) {
            if ([e isKindOfClass:NSDictionary.class] &&
                [e[@"pack_id"] isEqualToString:kLLLPackUUID]) return YES;
        }
    }
    return NO;
}

// 所有已存在的 global_resource_packs.json 全写一遍；一个都没存在才新建在根下
BOOL lllRegisterGlobalPack(void) {
    NSFileManager *fm = NSFileManager.defaultManager;
    NSUInteger written = 0;
    BOOL anyExisting = NO;

    for (NSString *p in globalPackJSONCandidates()) {
        if (![fm fileExistsAtPath:p]) continue;
        anyExisting = YES;

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
        if (out && [out writeToFile:p atomically:YES]) written++;
    }

    if (!anyExisting) {
        NSString *p = [neteaseGameBasePath() stringByAppendingPathComponent:@"global_resource_packs.json"];
        NSArray *arr = @[ @{ @"pack_id" : kLLLPackUUID, @"version" : @[@1, @0, @0] } ];
        NSData *out = [NSJSONSerialization dataWithJSONObject:arr
                                                      options:NSJSONWritingPrettyPrinted
                                                        error:nil];
        if (out && [out writeToFile:p atomically:YES]) written++;
    }

    return written > 0;
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
    if (!block) return;
    NSFileManager *fm = [NSFileManager defaultManager];

    NSSet *okExt = [NSSet setWithObjects:@"mp3", @"wav", @"m4a", @"aac",
                    @"flac", @"mp4", @"mov", @"ogg", nil];
    NSMutableSet *seen = [NSMutableSet set];

    // 先扫 Documents/music，没有就退到 Documents 根，防止用户直接丢在文档目录里
    for (NSString *dir in @[musicPath(), docsPath()]) {
        NSArray *items = [fm contentsOfDirectoryAtPath:dir error:nil];
        for (NSString *item in items) {
            if ([item hasPrefix:@"."]) continue;
            NSString *ext = item.pathExtension.lowercaseString;
            if (![okExt containsObject:ext]) continue;
            if ([seen containsObject:item]) continue;

            NSString *full = [dir stringByAppendingPathComponent:item];
            BOOL isDir = NO;
            if ([fm fileExistsAtPath:full isDirectory:&isDir] && !isDir) {
                [seen addObject:item];
                block(item, full);
            }
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

static NSString * const kLLLWatermarkText = @"\u8c6a\u86a7\u4e8c\u6539 \u00b7 \u4e91\u843d\u5236\u4f5c QQ\u7fa4:1071596112";

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
        _gradientLayer.locations = @[@(-0.5), @(-0.3), @(-0.1), @0.1, @0.3, @0.5];
        [self.layer addSublayer:_gradientLayer];

        // 动态流动：平移 locations，字面彩虹带一直在跑
        CABasicAnimation *flow = [CABasicAnimation animationWithKeyPath:@"locations"];
        flow.fromValue = @[@(-0.5), @(-0.3), @(-0.1), @0.1, @0.3, @0.5];
        flow.toValue   = @[@0.5, @0.7, @0.9, @1.1, @1.3, @1.5];
        flow.duration  = 3.2;
        flow.repeatCount = HUGE_VALF;
        flow.removedOnCompletion = NO;
        flow.timingFunction = [CAMediaTimingFunction functionWithName:kCAMediaTimingFunctionLinear];
        [_gradientLayer addAnimation:flow forKey:@"lll.gradient.flow"];

        _textLayer = [CATextLayer layer];
        _textLayer.string = kLLLWatermarkText;
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

    NSString *text = kLLLWatermarkText;
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
