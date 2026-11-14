# bbhj online

网易版《我的世界》iOS 资源注入器（Theos tweak）。

## 目录

```
bbhj-online/
├── VERSION.txt              当前版本 / SHA256 / 架构
├── README.md                本文件
├── docs/CHANGELOG.md        版本更新记录
├── dylib/
│   ├── bbhj-online-<ver>.dylib   带版本号的成品
│   ├── bbhj_online.dylib         同内容（注入器按这个名字加载）
│   └── bbhj-online-artifact.zip  CI 原始产物
└── source/                  完整可编译源码（Theos）
```

## 安装

1. 删除 `Frameworks/` 下所有旧的 `MaterialPackManager*.dylib`
2. 放入 `bbhj_online.dylib`（只放一份）
3. 重签 / 注入，启动游戏

## 自定义悬浮球图标

把 PNG 放到游戏沙盒 `Documents/bbhj_icon.png`，重启生效。删掉即恢复默认。

## 目录约定

| 路径 | 用途 |
|---|---|
| `Documents/Caizhi/` | 材质包（文件夹形式放入） |
| `Documents/mcp_plugins/` | MCP 插件 |
| `Documents/music/` | 本地音乐，同名 `.lrc` 自动加载歌词 |
| `Documents/LLL_runtime.log` | 运行日志 |
| `Documents/LLL_OFF` | 空文件 = 完全禁用插件 |
| `Documents/LLL_PATCH_BUJI` | 空文件 = 屏蔽 libBujiFix 的 bk_dl_req |
| `Documents/.lll_journal.json` | 注入账本（清理目标用） |
| `Documents/.lll_backup/` | 覆盖前备份 |

## 编译

```bash
cd source
export THEOS=~/theos
make clean all FINALPACKAGE=1 DEBUG=0 ARCHS="arm64 arm64e" TARGET="iphone:clang:latest:14.0"
```

或推送到 GitHub 由 Actions 自动构建（`.github/workflows/main.yml`）。

## 3.3 修复清单

| 问题 | 根因 | 处理 |
|---|---|---|
| 清缓存后灵动岛再也不出现 | `hide` 把整个 window 置 `hidden=YES`，`showIsland` 只把胶囊显示回来，window 一直是隐藏的 | `showIsland` 先恢复 `gWin.hidden = NO`；缓存状态改为"临时标题"盖在胶囊上，3 秒还原 |
| 灵动岛占全屏 / 遮挡游戏 | 宿主窗口整屏铺开，胶囊只是其中一小块 | 窗口尺寸 = 胶囊尺寸，展开时窗口跟着变大；宿主/根视图/胶囊同框 |
| 面板被刘海和 Home 条压住 | 卡片上下边距写死 20pt，忽略安全区 | 边距跟随 `safeAreaInsets`，`viewDidLayoutSubviews` 里实时校正 |
| 手机号登录大概率失败 | `params` 的 base64 用 `URLQueryAllowedCharacterSet`，`+` 没转义 → 服务端当空格 | 表单值走 RFC3986 严格编码（`LLLFormEncode`） |
| 关掉登录卡片后仍会突然弹"登录成功" | 二维码轮询没停 | `dismissCloudLoginCard` 里 `cancelLogin` |

## Folia 播放器（3.4 起）

音乐页整包换成 Folia 2.1.5 的前端（`core/folia-www.zip` 11MB，incbin 进 dylib）：

- 首次进音乐页解包到 `Documents/LLL/folia/www`（版本号写在 `version.txt`，升级会自动重解）
- `WKWebView` 用 `loadFileURL:allowingReadAccessToURL:` 打开 `index.html`，页面里全是相对路径，ES module 在 file:// 下正常解析
- 内联播放 + 不要求用户手势；进页面时把 `AVAudioSession` 设成 `Playback`，静音键开着也出声
- 切到别的页只 `hidden`，不销毁，播放/曲库状态都留着
- 原来的「外部播放器播放 (Folii)」开关和 `folii://` 跳转代码已删除

## 3.5 精简

- 删除网易云登录整条链路：`LLLCloudMusic.{h,m}`、`LLLCloudLogin.{h,m}`、`LOGIN.md`，以及面板/灵动岛上的所有「网易云」入口与 `cloudPlayer`
- 音乐页只跑 Folia，播放/曲库/歌词全部由 Folia 自己负责，不再有第二套播放器抢 AVAudioSession
- 灵动岛去掉 emoji：清缓存提示改纯文字，音量图标换 SF Symbol（`speaker.wave.*`）
