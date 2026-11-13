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
