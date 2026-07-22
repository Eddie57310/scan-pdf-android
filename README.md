# 文档扫描 (doc_scanner)

用手机相机把纸质文件扫描成 PDF。**自动检测边缘、自动纠偏 / 旋转**，一键生成 PDF 并可分享。
一套 Flutter 代码，同时支持 **iOS 和 Android**。

## 核心特性

- **打开即扫**：点一下就调起系统级扫描器
- **自动边缘检测 + 纠偏 + 旋转**：
  - iOS 用苹果原生 **VisionKit**（和"文件"App 里的扫描同款）
  - Android 用 **Google ML Kit 文档扫描器**
- **多页连拍**：一份文件可连续拍多页
- **一键生成 PDF**，自动按时间命名（`扫描_yyyyMMdd_HHmmss.pdf`）
- **保存 / 分享**：调用系统分享菜单（微信、邮件、文件 App 等）
- 首页列出历史扫描件，可打开预览、分享、删除

## 技术栈

| 用途 | 包 |
| --- | --- |
| 扫描内核（边缘检测 / 纠偏 / 旋转） | `cunning_document_scanner` |
| 生成 PDF | `pdf` |
| 存储路径 | `path_provider` |
| 分享 | `share_plus` |
| 打开预览 | `open_filex` |
| 时间格式化 | `intl` |

主程序：`lib/main.dart`

## 平台要求

- **Android**：minSdk 21（ML Kit 扫描器要求），已在 `android/app/build.gradle.kts` 设好
- **iOS**：iOS 13+（VisionKit 要求）；相机 / 相册权限说明已加入 `ios/Runner/Info.plist`

## 本机环境（已配好）

Flutter SDK、JDK 17、Android SDK 都装在用户目录下。开新终端先加载环境：

```bash
source ./env.sh
```

## 常用命令

```bash
flutter analyze                 # 静态分析
flutter test                    # 跑测试

flutter devices                 # 列出可用设备
flutter run                     # 插上安卓手机(开 USB 调试)直接运行

flutter build apk --release     # 编译正式安装包
# 产物: build/app/outputs/flutter-apk/app-release.apk
```

## 装到安卓手机

1. 手机开启「开发者选项 → USB 调试」，用数据线连电脑
2. `flutter devices` 确认能看到手机
3. `flutter run`（边改边热重载）或把 `app-release.apk` 拷到手机点击安装

## iOS 怎么出包？

Linux 上**无法**编译 iOS 安装包（苹果限制）。将来二选一：

1. **用一台 Mac**：装 Xcode，项目根目录 `flutter build ipa`
2. **云端 CI**（无需自备 Mac）：如 Codemagic / GitHub Actions 的 macOS runner，
   连上仓库自动出 iOS 包

代码是跨平台的，iOS 端无需改动，直接在 Mac / CI 上构建即可。
