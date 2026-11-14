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
| 网易云"显示在播放但没声音" | 接口给的 302 地址可能落到 403 页面，AVPlayer 静默失败 | 候选地址逐个 HEAD 探测（200/206 + audio/*），全挂才报错 |
| 灵动岛点"网易云"没反应 | 临时 new 的 MainViewController 没人持有，ARC 立刻回收，回调打在 nil 上 | 常驻宿主 `MainViewController.cloudHost`，浮窗创建时登记 |
| 关掉登录卡片后仍会突然弹"登录成功" | 二维码轮询没停 | `dismissCloudLoginCard` 里 `cancelLogin` |

## 外部播放器（Folii 路线）

设置里打开「外部播放器播放 (Folii)」后：网易云只负责登录、歌单、取流，
播放地址通过 `folii://play?url=` → `folii://open?url=` → `music://` → `qqmusic://`
依次交给已装的播放器；一个都没接住就回退内置 AVPlayer。
开关键：`LLL.externalPlayer`。
