//
//  LLLStealth.h
//  网易版检测规避：隐藏注入镜像名、过滤文件枚举、回掉 BujiFix 的 dl 请求函数。
//  只作用于本插件自己，不改游戏逻辑。
//

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

/// 进程启动早期调用一次（幂等）
void LLLStealthInstall(void);

/// 把 libBujiFix 的 bk_dl_req 打成 return；找不到符号就只记日志
BOOL LLLStealthPatchBuji(void);

NS_ASSUME_NONNULL_END
