//
//  ui/LLLUnblockServer.h
//  设备内本地换源服务：在 App 进程里起一个 http 服务（127.0.0.1:随机端口），
//  提供 /match 接口，行为与 tools/unblock_server.py 一致。
//
//  为什么要它：
//    换源逻辑本来就跑在客户端；把它包成 http 接口，是为了让「填地址」这条路
//    不依赖外网服务器 —— 地址就是本机回环。
//    同时 EXTERNAL 模式仍然可用（填自己电脑上跑的 python 服务）。
//

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

@interface LLLUnblockServer : NSObject

+ (instancetype)shared;

/// 当前监听端口，0 表示没起来
@property (nonatomic, assign, readonly) uint16_t port;

/// 启动/重启；返回是否成功
- (BOOL)start;
- (void)stop;

/// 本机回环地址，例如 http://127.0.0.1:18080；未启动返回 nil
- (nullable NSString *)localBaseURL;

/// 默认开启：面板里「解锁音源」留空时，自动用本地服务
- (BOOL)autoStartEnabled;
- (void)setAutoStartEnabled:(BOOL)on;

@end

NS_ASSUME_NONNULL_END
