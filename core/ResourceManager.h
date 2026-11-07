#import <Foundation/Foundation.h>
#import "BaseComponents.h"

@interface ResourceManager : NSObject
+ (void)injectMats:(NSArray<NSString*>*)paths names:(NSArray<NSString*>*)names cb:(void(^)(NSArray *ok, NSArray *fail))cb;
+ (void)injectPlugins:(NSArray<NSString*>*)paths names:(NSArray<NSString*>*)names type:(NSInteger)type cb:(void(^)(BOOL found, NSArray *ok, NSArray *fail))cb;
+ (void)cleanTarget:(void(^)(BOOL ok))cb;
+ (void)killCacheOnce:(void(^)(NSUInteger del, NSUInteger fail))cb;
+ (BOOL)copyDir:(NSString*)src to:(NSString*)dst;
@end
