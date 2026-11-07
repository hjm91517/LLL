//
//  EffectInjector.h
//  材质注入器 · 打击特效模块
//
//  生成一个自包含的 overlay 资源包（LLL_Effect），注入到已有目标目录里，
//  用于覆盖命中/暴击粒子，并按配置着色。幂等：同一份配置重复注入不会重写。
//

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

@interface EffectInjector : NSObject

/// 默认配置。键值与 UI 绑定，改这里就能改默认观感。
+ (NSDictionary *)defaultConfig;

/// 当前落盘配置（没有则返回 defaultConfig）
+ (NSDictionary *)currentConfig;

/// 保存配置并重新生成 overlay 包（后台队列，回调主线程）
+ (void)applyConfig:(NSDictionary *)cfg completion:(void (^_Nullable)(BOOL ok, NSString *_Nullable err))cb;

/// 把 overlay 包合并进已注入的目标目录（由 ResourceManager 调用）
+ (BOOL)mergeInto:(NSString *)targetDir;

/// overlay 包目录：Caizhi/LLL_Effect
+ (NSString *)packDir;

/// 是否已经生成过
+ (BOOL)isInstalled;

@end

NS_ASSUME_NONNULL_END
