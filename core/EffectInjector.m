//
//  EffectInjector.m
//

#import "EffectInjector.h"
#import "BaseComponents.h"
#import <UIKit/UIKit.h>
#import <CommonCrypto/CommonCrypto.h>

static NSString * const kCfgKey   = @"lll.effect.config";
static NSString * const kStateKey = @"lll.effect.state";
static const CGFloat kTextureSide = 16.0;

@implementation EffectInjector

#pragma mark - 配置

+ (NSDictionary *)defaultConfig {
    return @{
        @"enabled"    : @YES,
        @"r"          : @1.0,   // 0~1
        @"g"          : @0.35,
        @"b"          : @0.35,
        @"size"       : @0.12,  // 粒子边长（方块单位）
        @"count"      : @12,
        @"life"       : @0.45,  // 秒
        @"speed"      : @2.5,
        @"gravity"    : @-6.0,
        @"tintEntity" : @NO,    // 实验项：实体受击着色（需真机验证）
    };
}

+ (NSDictionary *)currentConfig {
    NSDictionary *d = [NSUserDefaults.standardUserDefaults dictionaryForKey:kCfgKey];
    if (!d) return [self defaultConfig];
    NSMutableDictionary *m = [[self defaultConfig] mutableCopy];
    [m addEntriesFromDictionary:d];
    return m;
}

#pragma mark - 路径

+ (NSString *)packDir {
    return [caizhiPath() stringByAppendingPathComponent:@"LLL_Effect"];
}

+ (BOOL)isInstalled {
    return [NSFileManager.defaultManager fileExistsAtPath:
            [[self packDir] stringByAppendingPathComponent:@"particles/crit.json"]];
}

#pragma mark - 生成

+ (void)applyConfig:(NSDictionary *)cfg completion:(void (^)(BOOL, NSString *))cb {
    NSDictionary *conf = cfg ?: [self defaultConfig];
    [NSUserDefaults.standardUserDefaults setObject:conf forKey:kCfgKey];

    dispatch_async(g_fileQueue(), ^{
        NSError *err = nil;
        BOOL ok = [self _render:conf error:&err];
        dispatch_async(dispatch_get_main_queue(), ^{
            if (cb) cb(ok, err.localizedDescription);
        });
    });
}

+ (BOOL)_render:(NSDictionary *)conf error:(NSError **)err {
    NSString *dir = [self packDir];
    NSString *statePath = [dir stringByAppendingPathComponent:@".lll_state"];
    NSString *sig = [self _signature:conf];

    // 幂等：配置没变且产物在，直接返回
    NSString *old = [NSString stringWithContentsOfFile:statePath encoding:NSUTF8StringEncoding error:nil];
    if ([old isEqualToString:sig] && [self isInstalled]) return YES;

    ensureDir(dir);
    ensureDir([dir stringByAppendingPathComponent:@"particles"]);
    ensureDir([dir stringByAppendingPathComponent:@"textures/particle"]);

    // 1. manifest（uuid 由配置签名派生，保证同一配置不换 uuid）
    NSString *uuid = [self _uuidFrom:sig];
    NSDictionary *manifest = @{
        @"format_version" : @2,
        @"header" : @{
            @"name" : @"LLL Effect",
            @"description" : @"打击特效 · 生成式",
            @"uuid" : uuid,
            @"version" : @[@1, @0, @0],
            @"min_engine_version" : @[@1, @20, @0],
        },
        @"modules" : @[ @{
            @"type" : @"resources",
            @"uuid" : [self _uuidFrom:[sig stringByAppendingString:@"#mod"]],
            @"version" : @[@1, @0, @0],
        } ],
    };
    if (![self _writeJSON:manifest to:[dir stringByAppendingPathComponent:@"manifest.json"] error:err]) return NO;

    // 2. 粒子：覆盖 crit（平砍暴击）与 hit（普攻）
    for (NSString *ident in @[@"minecraft:crit", @"minecraft:basic_crit_particle"]) {
        NSDictionary *p = [self _particleJSON:conf identifier:ident];
        NSString *name = [[ident componentsSeparatedByString:@":"] lastObject];
        name = [name stringByAppendingString:@".json"];
        if (![self _writeJSON:p to:[dir stringByAppendingPathComponent:
                                   [@"particles" stringByAppendingPathComponent:name]] error:err]) return NO;
    }

    // 3. 贴图：按配置着色生成一次
    NSString *png = [dir stringByAppendingPathComponent:@"textures/particle/lll_hit.png"];
    if (![self _writeTextureTo:png color:[self _color:conf]]) return [self _fail:err msg:@"生成贴图失败"];

    // 4. 实验项：实体受击着色（默认关闭）
    NSString *rc = [dir stringByAppendingPathComponent:@"render_controllers"];
    if ([conf[@"tintEntity"] boolValue]) {
        ensureDir(rc);
        NSDictionary *r = @{
            @"format_version" : @"1.10.0",
            @"render_controllers" : @{
                @"controller.render.player.third_person" : @{
                    @"geometry" : @"Geometry.default",
                    @"materials" : @[ @{ @"*" : @"Material.default" } ],
                    @"textures" : @[ @"Texture.default" ],
                    @"overlay_color" : @{
                        @"r" : conf[@"r"], @"g" : conf[@"g"], @"b" : conf[@"b"],
                        @"a" : @"query.is_hurt ? 0.55 : 0.0",
                    },
                },
            },
        };
        if (![self _writeJSON:r to:[rc stringByAppendingPathComponent:@"player.render_controllers.json"] error:err]) return NO;
    } else if ([[NSFileManager defaultManager] fileExistsAtPath:rc]) {
        [[NSFileManager defaultManager] removeItemAtPath:rc error:nil];
    }

    [sig writeToFile:statePath atomically:YES encoding:NSUTF8StringEncoding error:nil];
    return YES;
}

#pragma mark - 粒子模板

+ (NSDictionary *)_particleJSON:(NSDictionary *)c identifier:(NSString *)ident {
    NSNumber *r = c[@"r"], *g = c[@"g"], *b = c[@"b"];
    NSNumber *size = c[@"size"], *life = c[@"life"], *speed = c[@"speed"], *grav = c[@"gravity"];
    return @{
        @"format_version" : @"1.10.0",
        @"particle_effect" : @{
            @"description" : @{
                @"identifier" : ident,
                @"basic_render_parameters" : @{
                    @"material" : @"particles_alpha",
                    @"texture"  : @"textures/particle/lll_hit",
                },
            },
            @"components" : @{
                @"minecraft:emitter_local_space" : @{ @"position" : @NO, @"rotation" : @NO, @"velocity" : @NO },
                @"minecraft:emitter_rate_instant" : @{ @"num_particles" : c[@"count"] },
                @"minecraft:emitter_lifetime_once" : @{ @"active_time" : @0.1 },
                @"minecraft:emitter_shape_sphere" : @{ @"radius" : @0.25, @"direction" : @"outwards" },
                @"minecraft:particle_lifetime_expression" : @{ @"max_lifetime" : life },
                @"minecraft:particle_initial_speed" : speed,
                @"minecraft:particle_motion_dynamic" : @{
                    @"linear_acceleration" : @[ @0, grav, @0 ],
                    @"linear_drag_coefficient" : @1.6,
                },
                @"minecraft:particle_appearance_billboard" : @{
                    @"size" : @[ size, size ],
                    @"facing_camera_mode" : @"lookat_xyz",
                    @"uv" : @{
                        @"texture_width" : @16, @"texture_height" : @16,
                        @"uv" : @[ @0, @0 ], @"uv_size" : @[ @16, @16 ],
                    },
                },
                @"minecraft:particle_appearance_tinting" : @{
                    @"color" : @{
                        @"interpolant" : @"variable.particle_age / variable.particle_lifetime",
                        @"gradient" : @[
                            @{ @"0.0" : @[ r, g, b, @1.0 ] },
                            @{ @"0.7" : @[ r, g, b, @0.55 ] },
                            @{ @"1.0" : @[ r, g, b, @0.0 ] },
                        ],
                    },
                },
            },
        },
    };
}

#pragma mark - 贴图

+ (BOOL)_writeTextureTo:(NSString *)path color:(UIColor *)color {
    UIGraphicsImageRendererFormat *f = [UIGraphicsImageRendererFormat new];
    f.scale = 1; f.opaque = NO;
    UIGraphicsImageRenderer *r = [[UIGraphicsImageRenderer alloc] initWithSize:CGSizeMake(kTextureSide, kTextureSide) format:f];
    UIImage *img = [r imageWithActions:^(UIGraphicsImageRendererContext *ctx) {
        CGContextRef c = ctx.CGContext;
        CGFloat cs[4] = {0, 0, 0, 0};
        [color getRed:&cs[0] green:&cs[1] blue:&cs[2] alpha:&cs[3]];
        CGColorSpaceRef sp = CGColorSpaceCreateDeviceRGB();
        CGFloat comps[8] = { cs[0], cs[1], cs[2], 1.0, cs[0], cs[1], cs[2], 0.0 };
        CGFloat locs[2] = { 0.0, 1.0 };
        CGGradientRef grad = CGGradientCreateWithColorComponents(sp, comps, locs, 2);
        CGPoint mid = CGPointMake(kTextureSide / 2, kTextureSide / 2);
        CGContextDrawRadialGradient(c, grad, mid, 0.5, mid, kTextureSide / 2, 0);
        CGGradientRelease(grad); CGColorSpaceRelease(sp);
    }];
    return [UIImagePNGRepresentation(img) writeToFile:path atomically:YES];
}

#pragma mark - 工具

+ (UIColor *)_color:(NSDictionary *)c {
    return [UIColor colorWithRed:[c[@"r"] doubleValue]
                           green:[c[@"g"] doubleValue]
                            blue:[c[@"b"] doubleValue]
                           alpha:1.0];
}

+ (NSString *)_signature:(NSDictionary *)c {
    return [NSString stringWithFormat:@"%@|%@|%@|%@|%@|%@|%@|%@|%@",
            c[@"enabled"], c[@"r"], c[@"g"], c[@"b"], c[@"size"],
            c[@"count"], c[@"life"], c[@"speed"], c[@"gravity"]];
}

+ (NSString *)_uuidFrom:(NSString *)seed {
    unsigned char d[32];
    CC_SHA256(seed.UTF8String, (CC_LONG)seed.length, d);
    return [NSString stringWithFormat:
            @"%02x%02x%02x%02x-%02x%02x-%02x%02x-%02x%02x-%02x%02x%02x%02x%02x%02x",
            d[0],d[1],d[2],d[3], d[4],d[5], d[6],d[7], d[8],d[9],
            d[10],d[11],d[12],d[13],d[14],d[15]];
}

+ (BOOL)_writeJSON:(id)obj to:(NSString *)path error:(NSError **)err {
    NSData *d = [NSJSONSerialization dataWithJSONObject:obj options:NSJSONWritingPrettyPrinted error:err];
    if (!d) return NO;
    return [d writeToFile:path options:NSDataWritingAtomic error:err];
}

+ (BOOL)_fail:(NSError **)err msg:(NSString *)m {
    if (err) *err = [NSError errorWithDomain:@"LLLEffect" code:1 userInfo:@{NSLocalizedDescriptionKey : m}];
    return NO;
}

+ (BOOL)generateNow {
    return [self _render:[self currentConfig] error:nil];
}

+ (BOOL)mergeInto:(NSString *)targetDir {
    if (![self isInstalled]) return YES;              // 没启用特效就不影响注入
    NSString *src = [self packDir];
    NSFileManager *fm = NSFileManager.defaultManager;
    NSDirectoryEnumerator *e = [fm enumeratorAtPath:src];
    BOOL ok = YES;
    for (NSString *rel in e) {
        NSString *base = rel.lastPathComponent;
        if ([base isEqualToString:@".lll_state"]) continue;
        // 绝不能把特效包自己的 manifest 覆盖到目标包上，否则目标包 uuid 变了直接被游戏丢弃
        if ([base isEqualToString:@"manifest.json"] ||
            [base isEqualToString:@"pack_manifest.json"] ||
            [base isEqualToString:@"folder_md5.json"]) continue;
        NSString *s = [src stringByAppendingPathComponent:rel];
        NSString *d = [targetDir stringByAppendingPathComponent:rel];
        BOOL isDir = NO;
        if (![fm fileExistsAtPath:s isDirectory:&isDir] || isDir) continue;
        ensureDir(d.stringByDeletingLastPathComponent);
        [fm removeItemAtPath:d error:nil];
        if (![fm copyItemAtPath:s toPath:d error:nil]) ok = NO;
    }
    return ok;
}

@end
