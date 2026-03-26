# AIRSS（RssReader）鸿蒙应用市场发布指南

本文档详细说明了将 AIRSS 应用发布到华为鸿蒙应用市场（AppGallery Connect）的完整流程。

---

## 目录

1. [前置条件](#1-前置条件)
2. [第一步：完成开发者实名认证](#2-第一步完成开发者实名认证)
3. [第二步：在 AppGallery Connect 创建应用](#3-第二步在-appgallery-connect-创建应用)
4. [第三步：申请发布证书和 Profile](#4-第三步申请发布证书和-profile)
5. [第四步：在 DevEco Studio 中配置 Release 签名](#5-第四步在-deveco-studio-中配置-release-签名)
6. [第五步：构建 Release 包](#6-第五步构建-release-包)
7. [第六步：准备上架素材](#7-第六步准备上架素材)
8. [第七步：提交审核](#8-第七步提交审核)
9. [常见问题](#9-常见问题)

---

## 1. 前置条件

| 项目 | 当前状态 | 要求 |
|------|---------|------|
| 华为开发者账号 | ✅ 已注册 | 需完成实名认证 |
| DevEco Studio | ✅ 已安装 | 建议使用最新版本 |
| HarmonyOS SDK | ✅ API 6.0 | 已满足 |
| 应用包名 | `com.dizzy.rssreader` | 确保唯一，发布后不可更改 |
| 网络环境 | - | 需能访问华为开发者联盟网站 |

---

## 2. 第一步：完成开发者实名认证

### 2.1 登录开发者联盟

1. 访问 [华为开发者联盟](https://developer.huawei.com/consumer/cn/)
2. 使用已注册的华为账号登录
3. 进入 **管理中心** → **认证信息**

### 2.2 选择认证类型

| 认证类型 | 适用场景 | 所需材料 | 审核时间 |
|---------|---------|---------|---------|
| **个人开发者** | 个人独立开发 | 身份证正反面照片、手持身份证照片 | 1-3 个工作日 |
| **企业开发者** | 公司/团队开发 | 营业执照、法人身份证、对公银行账号 | 3-5 个工作日 |

### 2.3 个人开发者认证步骤

1. 在管理中心选择 **个人开发者认证**
2. 填写真实姓名、身份证号码
3. 上传身份证正面、反面照片（要求清晰、完整、无遮挡）
4. 上传手持身份证照片（本人手持，五官和证件信息清晰可见）
5. 填写联系方式（手机号、邮箱）
6. 提交并等待审核

> ⚠️ **注意**: 认证信息必须与华为账号注册信息一致。认证通过后，开发者名称将显示在应用市场中。

### 2.4 缴纳开发者费用

- 个人开发者：**免费**
- 企业开发者：可能需要缴纳年费（具体以华为最新政策为准）

---

## 3. 第二步：在 AppGallery Connect 创建应用

### 3.1 登录 AGC

1. 访问 [AppGallery Connect](https://developer.huawei.com/consumer/cn/service/josp/agc/index.html)
2. 使用已认证的开发者账号登录

### 3.2 创建项目（如尚未创建）

1. 在 AGC 控制台首页，点击 **我的项目**
2. 点击 **添加项目**，输入项目名称（如 `AIRSS`）
3. 根据需要选择是否开启分析服务

### 3.3 创建应用

1. 在项目中，点击 **添加应用**
2. 填写以下信息：

| 字段 | 填写内容 |
|------|---------|
| 平台 | HarmonyOS |
| 设备 | 手机 |
| 应用名称 | AIRSS |
| 应用包名 | `com.dizzy.rssreader` |
| 应用分类 | 工具 → 阅读/新闻 |
| 默认语言 | 简体中文 |

3. 点击 **确定** 创建应用

> ⚠️ **重要**: 包名（bundleName）必须与 `AppScope/app.json5` 中的 `bundleName` 完全一致，即 `com.dizzy.rssreader`。创建后不可更改。

---

## 4. 第三步：申请发布证书和 Profile

### 4.1 概念说明

| 名称 | 说明 |
|------|------|
| **发布证书 (Release Certificate)** | 用于对应用进行签名，证明应用来源可信 |
| **发布 Profile (Release Profile)** | 包含应用的包名、证书信息和权限，限定应用的运行范围 |

### 4.2 生成密钥库和 CSR 文件

#### 方式一：通过 DevEco Studio 生成（推荐）

1. 打开 DevEco Studio
2. 菜单栏 → **Build** → **Generate Key and CSR**
3. **创建密钥库 (Key Store)**：
   - 选择 **New** 创建新密钥库
   - 设置存储路径（建议：`~/.ohos/config/release_rssreader.p12`）
   - 设置密钥库密码（**务必牢记**）
4. **创建密钥 (Key)**：
   - Key Alias：`releaseKey`（或自定义名称）
   - 密钥密码（**务必牢记**）
5. **生成 CSR 文件**：
   - 选择保存路径
   - 点击 **Generate** 生成 `.csr` 文件

#### 方式二：通过命令行生成

```bash
# 生成密钥库
keytool -genkeypair -alias "releaseKey" -keyalg EC -sigalg SHA256withECDSA \
  -dname "C=CN,O=YourName,OU=YourUnit,CN=AIRSS" \
  -keystore ~/.ohos/config/release_rssreader.p12 \
  -storetype pkcs12 -storepass <你的密码> -keypass <你的密码>

# 生成 CSR
keytool -certreq -alias "releaseKey" \
  -keystore ~/.ohos/config/release_rssreader.p12 \
  -storetype pkcs12 -storepass <你的密码> \
  -file ~/.ohos/config/release_rssreader.csr
```

### 4.3 在 AGC 申请发布证书

1. 登录 AGC → **用户与访问** → **证书管理**
2. 点击 **新增证书**
3. 填写信息：
   - 证书名称：`AIRSS_Release`
   - 证书类型：**发布证书**
   - 上传步骤 4.2 中生成的 `.csr` 文件
4. 点击 **提交**，下载生成的 `.cer` 证书文件
5. 将证书保存到：`~/.ohos/config/release_rssreader.cer`

### 4.4 在 AGC 申请发布 Profile

1. AGC → **用户与访问** → **Profile管理**
2. 点击 **添加**
3. 填写信息：

| 字段 | 填写内容 |
|------|---------|
| Profile 名称 | `AIRSS_Release_Profile` |
| 类型 | 发布 |
| 包名 | 选择 `com.dizzy.rssreader` |
| 证书 | 选择步骤 4.3 申请的 `AIRSS_Release` |
| 权限 | 勾选 `ohos.permission.INTERNET` |

4. 点击 **提交**，下载生成的 `.p7b` Profile 文件
5. 将 Profile 保存到：`~/.ohos/config/release_rssreader.p7b`

---

## 5. 第四步：在 DevEco Studio 中配置 Release 签名

### 5.1 自动配置方式（推荐）

1. 打开 DevEco Studio
2. 菜单栏 → **File** → **Project Structure** → **Signing Configs**
3. 取消勾选 **Automatically generate signature**
4. 选择 **Release** 签名配置
5. 分别填入：
   - **Store File**: 密钥库文件路径（`.p12`）
   - **Store Password**: 密钥库密码
   - **Key Alias**: `releaseKey`
   - **Key Password**: 密钥密码
   - **Sign Alg**: `SHA256withECDSA`
   - **Cert Path**: 证书文件路径（`.cer`）
   - **Profile**: Profile 文件路径（`.p7b`）
6. 点击 **Apply** → **OK**

### 5.2 手动配置方式

DevEco Studio 会自动修改 `build-profile.json5`，你也可以手动编辑。

项目根目录 `build-profile.json5` 中的 `signingConfigs` 数组中已预留了 `release` 配置项（见本项目的配置调整），你需要将其中的 `TODO` 占位符替换为实际路径和密码：

```json5
{
  "name": "release",
  "type": "HarmonyOS",
  "material": {
    "certpath": "TODO: 替换为 .cer 证书文件的绝对路径",
    "keyAlias": "releaseKey",
    "keyPassword": "TODO: 替换为密钥密码（DevEco Studio 会自动加密）",
    "profile": "TODO: 替换为 .p7b Profile 文件的绝对路径",
    "signAlg": "SHA256withECDSA",
    "storeFile": "TODO: 替换为 .p12 密钥库文件的绝对路径",
    "storePassword": "TODO: 替换为密钥库密码（DevEco Studio 会自动加密）"
  }
}
```

> 💡 **提示**: 建议通过 DevEco Studio 的 Project Structure 界面配置，它会自动加密密码。手动填写明文密码存在安全风险。

---

## 6. 第五步：构建 Release 包

### 6.1 通过 DevEco Studio 构建

1. 确保签名配置正确
2. 菜单栏 → **Build** → **Build Hap(s)/APP(s)** → **Build APP(s)**
3. 选择 **release** 构建模式
4. 等待构建完成
5. 输出路径：`entry/build/default/outputs/default/entry-default-signed.app`

### 6.2 通过命令行构建

```bash
# 确保在项目根目录
cd /Users/dizzychen/DevEcoStudioProjects/RssReader

# 构建 release APP 包（用于上架应用市场）
hvigorw assembleApp --mode module -p module=entry@default -p buildMode=release --no-daemon
```

或使用项目中的构建脚本：

```bash
./run_build.sh release
```

### 6.3 构建产物说明

| 文件类型 | 用途 | 说明 |
|---------|------|------|
| `.hap` | 单模块包 | 用于设备端安装测试 |
| `.app` | 应用包 | **用于上传到 AppGallery Connect** |

> ⚠️ **重要**: 上传到应用市场的必须是 `.app` 文件，不是 `.hap` 文件。

---

## 7. 第六步：准备上架素材

### 7.1 必要素材清单

| 素材 | 要求 | 说明 |
|------|------|------|
| **应用图标** | 216×216 px, PNG, 圆角 | 与应用内图标一致 |
| **应用截图** | 至少 3 张，最多 8 张 | 手机竖屏截图，展示核心功能 |
| **应用描述** | 简介 ≤80 字，详情 ≤4000 字 | 准确描述应用功能 |
| **应用分类** | 工具/阅读类 | 选择最匹配的分类 |
| **版本说明** | ≤500 字 | 首版可填「首次发布」 |
| **隐私政策 URL** | 必须提供有效链接 | 详见 7.3 |
| **客服联系方式** | 邮箱或电话 | 用户反馈渠道 |

### 7.2 推荐截图内容

建议截取以下功能页面的截图：

1. **首页** — 展示文章列表和整体界面
2. **订阅管理** — 展示订阅源列表和分组功能
3. **文章详情** — 展示文章阅读界面
4. **搜索功能** — 展示搜索和筛选功能
5. **收藏页面** — 展示收藏文章管理

截图要求：
- 分辨率：1080×2340 px 或更高
- 格式：PNG 或 JPG
- 不要包含状态栏中的个人信息
- 建议使用真机截图或 DevEco Studio 模拟器截图

### 7.3 隐私政策

鸿蒙应用市场**强制要求**提供隐私政策。由于本应用使用了以下权限/功能，隐私政策中需要说明：

| 权限/功能 | 隐私政策中需说明 |
|-----------|----------------|
| `ohos.permission.INTERNET` | 应用通过网络获取 RSS 订阅源内容 |
| 本地数据库存储 | 应用在本地存储用户的订阅源、文章和收藏数据 |
| 系统通知 | 应用在有新文章时发送通知提醒 |

你需要准备一个可公开访问的隐私政策页面 URL。你可以：
- 在 GitHub Pages 上托管一个隐私政策页面
- 使用第三方隐私政策生成器
- 自行搭建网页

隐私政策应至少包含：
- 收集的数据类型（本应用不收集用户个人数据）
- 数据用途说明
- 数据存储方式（仅本地存储）
- 第三方 SDK 说明（本应用无第三方数据 SDK）
- 联系方式

### 7.4 应用描述参考

**应用名称**：AIRSS

**一句话简介（≤80字）**：
> AIRSS — AI 驱动的智能 RSS 阅读器，自动总结文章、个性化推荐、生成阅读画像，让你的每一次阅读都有价值。

**详细描述**：

> AIRSS 是一款专为 HarmonyOS NEXT 打造的 AI 智能 RSS 阅读器。它不仅是一个 RSS 订阅工具，更是你的私人阅读助手——通过 AI 理解你的阅读偏好，让信息主动适配你。
>
> **🤖 AI 智能能力**
> • AI 文章总结：进入文章详情自动生成摘要，流式打字机效果，快速把握核心观点
> • AI 智能推荐：根据你的阅读画像和兴趣偏好，个性化排序文章
> • AI 每日简报：一键生成今日阅读推荐与综述，不错过重要内容
> • AI 阅读画像：30 天行为数据深度分析，生成你的专属阅读画像
> • 支持 5 种 AI 提供商：通义千问、OpenAI、DeepSeek、Groq、自定义（兼容 Ollama 本地部署）
>
> **📖 核心阅读功能**
> • 支持 RSS 2.0、Atom、RDF 三种格式自动识别与解析
> • 最新 / 推荐双 Tab 切换，时间线与智能推荐自由选择
> • 图文混排正文渲染 + 应用内 WebView 原文查看
> • 400ms 防抖实时搜索，关键词快速定位
> • 文章收藏、已读管理、仅未读过滤
> • 三档字体大小切换，舒适阅读体验
> • 文章反馈评价（有价值 / 不感兴趣），持续优化推荐
>
> **🧠 三层记忆系统**
> • 灵魂档案：手动编辑你的阅读偏好与兴趣领域，作为 AI 个性化的基础
> • 阅读画像：系统自动生成的兴趣权重、话题偏好和阅读风格分析
> • 行为日志：全链路追踪阅读、收藏、跳过、评价、搜索行为，越用越懂你
>
> **📊 阅读数据统计**
> • 30 天总览：阅读天数、文章数、收藏数、搜索次数、日均阅读、平均阅读时长
> • 最近 7 天每日明细，直观了解阅读习惯
>
> **🔧 订阅管理**
> • 订阅源分组管理，未读角标一目了然
> • OPML 标准格式导入导出，轻松迁移订阅
> • 后台自动刷新 + 新文章系统通知
> • 可配置刷新间隔、每源缓存数量
>
> **🔒 隐私保护**
> • 纯本地数据存储，不收集任何用户个人信息
> • AI 功能可选配置，不使用 AI 也能正常阅读
> • 记忆数据支持一键导出和清除
>
> 让 AI 成为你的阅读伙伴，从信息过载中解放出来。

**关键词**：RSS阅读器、AI总结、智能推荐、新闻聚合、订阅管理、阅读画像、每日简报、信息流、OPML

---

## 8. 第七步：提交审核

### 8.1 上传应用包

1. 登录 [AppGallery Connect](https://developer.huawei.com/consumer/cn/service/josp/agc/index.html)
2. 进入 **我的应用** → 选择 `AIRSS`
3. 点击左侧 **应用信息**，完善基础信息
4. 点击左侧 **版本信息与管理** → **准备提交**
5. 在 **软件包管理** 区域，点击 **上传**
6. 选择构建好的 `.app` 文件上传
7. 等待上传完成并通过包检测

### 8.2 填写版本信息

在版本信息页面依次填写：

1. **语言与地区**：选择支持的地区和语言
2. **应用名称**：AIRSS
3. **应用图标**：上传 216×216 图标
4. **简介**：填写应用简介
5. **应用截图**：上传 3-8 张截图
6. **应用分类**：选择合适的分类
7. **内容分级**：根据应用内容选择适当分级（本应用建议选择"全年龄"）
8. **隐私政策**：填写隐私政策 URL
9. **版本说明**：填写此版本的更新内容

### 8.3 提交审核

1. 检查所有必填项是否完成（页面会提示未完成项）
2. 点击 **提交审核**
3. 确认提交

### 8.4 审核周期

| 阶段 | 时间 |
|------|------|
| 初审（机器检测） | 数小时内 |
| 人工审核 | 1-3 个工作日 |
| 全流程 | 通常 1-5 个工作日 |

### 8.5 审核被拒常见原因

| 原因 | 解决方式 |
|------|---------|
| 缺少隐私政策 | 补充有效的隐私政策 URL |
| 权限使用不合理 | 确保申请的权限都有实际使用场景 |
| 应用崩溃/ANR | 充分测试后再提交 |
| 截图与实际不符 | 使用真实截图 |
| 应用描述不准确 | 如实描述应用功能 |
| 应用内容违规 | 确保 RSS 内容展示符合规范 |

---

## 9. 常见问题

### Q1：debug 签名和 release 签名可以共存吗？
**可以。** 项目的 `build-profile.json5` 中同时配置了 `default`（debug）和 `release` 两个签名配置，日常开发使用 debug 签名，发布时切换到 release 签名即可。

### Q2：包名创建后可以修改吗？
**不可以。** `com.dizzy.rssreader` 一旦在 AGC 创建应用后就不能更改。如果需要更换包名，只能创建新的应用。

### Q3：应用更新需要重新申请证书吗？
**不需要。** 同一个发布证书可用于该应用的后续所有版本更新。只需要升级 `versionCode` 和 `versionName`。

### Q4：如何更新应用版本？
1. 修改 `AppScope/app.json5` 中的 `versionCode`（必须递增）和 `versionName`
2. 使用同一个 release 签名重新构建
3. 在 AGC 中创建新版本并上传

### Q5：代码混淆会影响应用功能吗？
本项目已配置了合理的混淆规则（属性混淆、顶级混淆、文件名混淆、导出混淆），**建议在发布前充分测试 release 包**，确保混淆不影响功能。如果发现问题，可在 `entry/obfuscation-rules.txt` 中添加 keep 规则。

### Q6：`ohos.permission.INTERNET` 权限需要特别处理吗？
`INTERNET` 权限属于普通权限（normal），不需要动态申请，在 `module.json5` 中声明即可。但在 AGC 提审时需要说明该权限的用途（获取 RSS 订阅源内容）。

---

## 操作检查清单

按顺序完成以下步骤：

- [ ] 完成华为开发者实名认证
- [ ] 在 AGC 创建项目和应用
- [ ] 生成密钥库和 CSR 文件
- [ ] 在 AGC 申请发布证书
- [ ] 在 AGC 申请发布 Profile
- [ ] 在 DevEco Studio / build-profile.json5 配置 release 签名
- [ ] 将 `build-profile.json5` 中 release 签名的 TODO 占位符替换为实际值
- [ ] 构建 release `.app` 包
- [ ] 安装 release 包到真机测试，确保功能正常
- [ ] 准备应用图标（216×216）
- [ ] 截取 3-5 张应用截图
- [ ] 准备隐私政策页面并获取 URL
- [ ] 在 AGC 上传 `.app` 包
- [ ] 填写完整的版本信息
- [ ] 提交审核
- [ ] 等待审核通过 🎉
