
#import <Foundation/Foundation.h>

void setCacheCleanerEnabled(BOOL enabled);
BOOL isCacheCleanerEnabled(void);

/// v2.2 灵动岛「清缓存」按钮手动触发一次清理（无需开启自动监控）
void LLLCacheCleanNow(void);