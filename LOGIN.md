# 网易云登录思路（v2.4）

## 三种入口
播放器卡片上的「网易云」按钮，或灵动岛展开态的「网易云」按钮 → 登录面板。

## 1. 扫码（主路径，明文接口就够）
```
GET  /api/login/qrcode/unikey?type=3   // PC 客户端码；失败退 type=1
     → {"code":200,"unikey":"a2c1…"}
二维码内容  https://music.163.com/login?codekey=<unikey>
GET  /api/login/qrcode/client/login?key=<unikey>&type=3
     800 待扫码 / 801 已扫码待确认 / 802 已取消 / 803 成功
```
2s 轮询一次，120 次（4 分钟）超时，可随时取消。803 之后 `MUSIC_U` 已经在 cookie 里。

## 2. 手机号 + 密码（必须加密）
明文 `/api/login/cellphone` 现在返回 `401 无权限访问. ENC`，所以走 `weapi`：
```
params    = base64( AES-128-CBC(json, key=随机16位, iv=0102030405060708) )
encSecKey = hex( RSA_raw(reverse(随机16位)) )      // 1024 位裸 RSA，无填充
POST /weapi/login/cellphone?csrf_token=
body: params=<...>&encSecKey=<...>
json: {"phone":"…","countrycode":"86","password":md5(明文),"rememberLogin":"true"}
```
iOS 侧实现：`SecKeyCreateWithData` 吃现场拼的 DER(SPKI) 公钥，加密用
`SecKeyCreateEncryptedData(kSecKeyAlgorithmRSAEncryptionRaw)` —— 正好等价于裸 RSA。
AES 用 CommonCrypto 的 `CCCrypt(kCCAlgorithmAES, kCCOptionPKCS7Padding)`。

## 3. 粘贴 Cookie（兜底）
解析 `MUSIC_U=…; __csrf=…` → 写进 `NSHTTPCookieStorage`（domain `.music.163.com`）→
`/api/nuser/account/get` 验活，拿昵称/uid。

## 登录后
- 我喜欢的音乐：`/api/user/playlist` 找 `specialType==5` → `/api/v6/playlist/detail`
- 搜索：`/api/search/get?s=…&type=1`
- 取流：`/api/song/enhance/player/url?ids=[id]&br=320000`，无 url 时回退
  `/song/media/outer/url?id=<id>.mp3`（版权/会员限制会失败，界面给明确提示）
- 封面：`al.picUrl` 异步下载后喂给灵动岛

## 状态归属
所有播放都写进 `LLLNowPlaying`（歌名/歌手/封面/时长/进度/播放态），
灵动岛只读它；岛上的播放/切歌/拖动条通过 `LLLNPCommand` 回到播放器。

## 4. 外部播放器（v3.3）

登录和取流留在插件里，播放交给别的 App —— 典型就是 Folii：
```
folii://play?url=<urlencode(直链)>
folii://open?url=<...>          // 部分版本只认这个
folii://x-callback-url/play?url=<...>
music://<直链>                  // 系统音乐
qqmusic://qq.com/ui/openUrl?url=<...>
```
依次尝试，`openURL` 回调 false 就换下一个；全失败弹提示并回退内置 `AVPlayer`。
直链先做 HEAD 探测（`200/206` + `audio/*` 且长度 > 32KB），403 页面直接丢弃。
