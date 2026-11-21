# 熊猫单词原生客户端

本目录是从 D:/code/panda-word-front-end 迁移的独立原生代码，原 Vue 项目没有修改。

- iOS：SwiftUI，最低 iOS 16；打开 ios/PandaWord.xcodeproj。
- 鸿蒙：ArkTS / ArkUI Stage 模型，最低 HarmonyOS NEXT 5.0 / API 12；用 DevEco Studio 打开 harmony。
- 两端直接调用旧版后端，界面不使用 WebView。查询外部词典时打开系统浏览器。

## 已迁移功能

手机号登录、验证码注册、找回密码、隐私政策、今日背词、隐藏/显示释义、官方释义及例句、自定义释义、服务端发音、认识/模糊/忘记、分组词库、选词/全选、添加学习计划、会员等级与原版会员说明展示、学习记录刷新及上传、反馈、退出登录、二次确认注销账号。

保存复习等级或释义时，先等待后端成功再更新本地页面。保留完整原始学习记录中的其他字段，避免更新接口丢失未知字段。时间戳使用毫秒，复习间隔与旧版一致，认识最高12级、模糊最低0级、忘记归零。

iOS 使用 Keychain 保存 token；鸿蒙当前为内存会话，应用进程退出后需要重新登录。手机号和密码只用于请求，不写入配置。

## iOS 构建

1. 在安装 Xcode 的 Mac 上打开 ios/PandaWord.xcodeproj。
2. 选择 PandaWord target，在 Signing & Capabilities 中选择自己的开发团队；有需要时修改 bundle identifier。
3. 选择 iOS 16 或更新的模拟器，运行。
4. 真机需要有效的签名配置。

项目同时提供 ios/project.yml，可选用 XcodeGen 重新生成工程；无需 XcodeGen 也能直接打开现有工程。

Mac 自动检查：

~~~sh
sh scripts/check-ios.sh
~~~

先执行原生 CommonCrypto 与旧版 CryptoJS 的加密向量对比，再编译模拟器应用。

## 鸿蒙构建

1. 安装带 HarmonyOS API 12 或更新 SDK 的 DevEco Studio，打开 harmony。
2. Sync Project。工程使用 5.0.0 模型，Hvigor 来自 IDE 配套工具，不额外安装 npm 版本的插件。
3. 在 File > Project Structure 配置本机 SDK 和签名。不得把本机 local.properties 或证书提交到仓库。
4. 使用 API 12 或更新的 HarmonyOS NEXT 模拟器运行 entry；真机使用 IDE 配置自动签名。

该项目面向原生 HarmonyOS NEXT，不是旧版 Android 兼容层的 APK。

## 接口与兼容检查

默认 API：http://47.97.107.100:8088/api/ 。可以在登录页修改。默认地址和 AES key/IV 均继承原项目，不代表后端已联调通过。未向真实服务器发送注册、验证码、修改密码或删除账号请求。

~~~sh
node scripts/verify.cjs
~~~

当前已通过：120 组复习间隔边界与原算法对照、5 组旧版 CryptoJS 加密向量与标准 AES/CBC/ZeroPadding 对照、JSON 配置解析、Xcode 对象引用、鸿蒙页面入口和文字编码检查。

reference/aes-vectors.json 使用虚构测试输入；请在鸿蒙调试测试中调用 Api.ets 中的 encrypt 对照这些向量。Windows 上的检查不等于两端原生编译通过。

## 尚待完成的发布工作

- 当前机器没有 Xcode、DevEco SDK 或 Hvigor，因此未完成原生编译、模拟器/真机验证、签名或 IPA/HAP 产物生成；首次打开工程仍可能需要按实际 SDK 版本调整配置。
- 需要用测试账号联调所有接口，尤其是 load/adv 的实际返回字段、会员额度、登录过期、保存失败重试、音频播放和账号注销。
- VIP 页面保留旧版支付宝二维码和价格说明，但没有新增支付下单或支付回调，也未实现 StoreKit 或鸿蒙 IAP。原版价格未经过在线核验，发布前需要核对会员方案及平台购买流程。会员状态由后端返回。
- 旧版 SVIP 管理员设置他人会员的入口未移入移动端。
- 已迁移官方释义、短语和例句；iOS 提供欧路、有道、金山入口，鸿蒙目前提供欧路入口。
- 隐私政策原文从旧项目复制，保留原文的“红狐单词”名称和日期；发布前需要由产品方核对品牌、联系人及数据处理描述。
- 为兼容现有 HTTP 后端，iOS 开发配置允许 HTTP；上线前应由后端提供 HTTPS，并收紧 Info.plist 中的 ATS 配置。

参考：[SwiftUI](https://developer.apple.com/documentation/swiftui)、[鸿蒙 module.json5](https://developer.huawei.com/consumer/en/doc/doccenter-getting-started/module-configuration-file/)、[Hvigor 配置](https://developer.huawei.com/consumer/en/doc/harmonyos-guides/ide-hvigor-set-options/)。
