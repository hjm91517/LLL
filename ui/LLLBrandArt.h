#import <UIKit/UIKit.h>

NS_ASSUME_NONNULL_BEGIN

/// 灵动岛封面位用的网易云品牌图标（懒加载 + 缓存）。
/// 查找顺序：宿主 App 里的 LLLCloudBrand.png → Documents/LLLCloudBrand.png →
/// 内置兜底（红底白音符，网易云配色），保证胶囊里永远不是空灰块。
UIImage *LLLCloudBrandImage(void);

NS_ASSUME_NONNULL_END
