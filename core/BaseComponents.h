#import <UIKit/UIKit.h>
#import <AVFoundation/AVFoundation.h>
#import "AppTheme.h"

@interface PackCell : UITableViewCell
@property (nonatomic, strong) UIView *card;
@property (nonatomic, strong) UIImageView *icon;
@property (nonatomic, strong) UILabel *title, *sub;
@property (nonatomic, strong) UIButton *btn;
@end

@interface PluginCell : UITableViewCell
@property (nonatomic, strong) UIView *card;
@property (nonatomic, strong) UILabel *title;
@property (nonatomic, strong) UIButton *btn;
@end

@interface QueueCell : UITableViewCell
@property (nonatomic, strong) UIView *card;
@property (nonatomic, strong) UILabel *idx, *title;
@property (nonatomic, strong) UIImageView *drag;
@end

#define INCBIN_SILENCE_BITCODE_WARNING
#define INCBIN_PREFIX cw
#define INCBIN_STYLE INCBIN_STYLE_SNAKE
#include "incbin.h"
INCBIN(ErrorImage, "cw.png");
INCBIN(FloatIcon, "png.png");

extern BOOL gLLLDuplicateLoad;
extern CGFloat const kIconSize;
extern NSString * const kQueueNamesKey, * const kQueuePathsKey,
                * const kPluginQueueNamesKey, * const kPluginQueuePathsKey;

dispatch_queue_t g_fileQueue(void);
UIImage* errorImage(void);
UIImage* floatIcon(void);
UIImage* customFloatIcon(void);
NSString* customFloatIconPath(void);
NSString* customFloatIconPath(void);
UIImage* cachedIcon(NSString *path, BOOL hasIcon);

NSString* docsPath(void);
NSString* caizhiPath(void);
NSString* mcpPluginsPath(void);
NSString* targetPath(void);
NSString* targetPathDisplayName(void);
NSString* resourcePacksRootPath(void);
NSArray<NSString*>* detectLegacyPatchDirs(void);
BOOL lllEnsureInjectPackManifest(void);
BOOL lllRegisterGlobalPack(void);
BOOL lllInjectPackRegistered(void);
NSArray<NSString*>* candidateGameBases(void);
void lllResetPathCache(void);
void lllLog(NSString *fmt, ...);
NSArray<NSString*>* injectionTargetDirs(void);
void lllLogDirectorySnapshot(void);
BOOL lllEnsurePackManifestAt(NSString *dir);
NSString* packcacheBasePath(void);
NSArray<NSString*>* findAllMCPTargets(void);
NSArray<NSString*>* behaviorPacksDirs(void);
NSArray<NSString*>* globalPackJSONCandidates(void);
NSArray<NSString*>* legacyPatchDirs(void);
NSArray<NSString*>* hotPatchPackDirs(void);
NSArray<NSString*>* userResourcePackDirs(void);
NSString* lllPackDirName(void);
BOOL lllStripSignatures(NSString *dir);
void lllLogPackRootFiles(NSString *dir);
BOOL lllRewriteFolderMD5(NSString *dir);
NSString *LLLStableKeyPublic(NSString *s);
void lllMD5CacheSave(void);
NSString* findBugudaoTarget(void);
NSArray<NSString*>* findAllBugudaoTargets(void);
NSArray<NSString*>* findAllMisakiTargets(void);
NSString* neteaseGameBasePath(void);
NSString* pfPath(void);
void ensureDir(NSString *path);

void scanPacks(void(^)(NSString *, NSString *, BOOL));
void scanPlugins(void(^)(NSString *, NSString *));

NSString* musicPath(void);
void scanMusicFiles(void(^)(NSString *name, NSString *path));

NSRegularExpression* killenRegex(void);

NSString* backgroundsDir(void);
NSArray<NSString*>* backgroundFiles(void);

@interface MaterialHUD : UIView
+ (void)show:(NSString *)text inView:(UIView *)view;
+ (void)dismiss;
@end
void PlayHaptic(BOOL success);
void PlayHapticWarning(void);
void ShowToast(NSString *msg, NSTimeInterval dur, BOOL bottomRight, BOOL isError);

void showWatermark(void);
void hideWatermark(void);
void setWatermarkEnabled(BOOL enabled);
BOOL isWatermarkEnabled(void);

@interface BaseOverlayWindow : UIWindow
@end
