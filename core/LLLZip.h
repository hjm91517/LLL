//
//  LLLZip.h
//  纯 zlib 的 zip 解包 + 材质包自动导入（.zip / .mcpack）
//

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

@interface LLLZip : NSObject

/// 解到 destDir（不存在会建）。返回写出的文件相对路径列表。
+ (nullable NSArray<NSString *> *)extract:(NSString *)zipPath
                                       to:(NSString *)destDir
                                    error:(NSString *_Nullable *_Nullable)err;

/// 扫 Documents/ 和 Documents/Caizhi/ 下的压缩包，解到 Caizhi/<包名>，成功后删压缩包。
+ (NSUInteger)importPendingArchives;

@end

NS_ASSUME_NONNULL_END
