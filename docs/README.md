# 今日待办

面向大学生的碎片事务提醒工具 —— **打开就看清今天要做什么**。

> ⚠️ **路线变更（2026-09-23 决定）**：本项目由 Web 版改为 **Flutter 安卓 App**，完全替换旧 Web 版。
> 下面的「怎么运行」起针对新路线；旧 Web 版见文末「历史」一节。
>
> **当前状态**：阶段 1（环境搭建）与阶段 2（工程骨架 + 模拟器跑通）均已完成——Flutter 3.47.5 + Android SDK 36.0.0 + Android Studio 2026.1.4，工程位于 `D:\dev\today_todo`，**已能在模拟器上构建、安装、运行，并实测热重载 351 ms**。
> 下一步是阶段 3：用「今日待办」的实际功能替换工程里的官方示例代码（F1–F4）。

## 为什么做这个

大学里的琐事都是小事，但不做就会变成麻烦：水卡不充值会停水，衣服不洗会发霉，作业不看截止日期会错过。

这些事的共同点：**单件事成本极低（一两分钟就做完），但遗忘的代价很高。**

问题不是「没有地方记」，而是「记了之后没有一个恰当的时机被看见」。这个工具只解决这一句话。

所以它不做成功能更多的待办工具，而是做成**信息层级更清楚的**待办工具。

## 怎么运行

### 前置条件（本机已就绪）

- **Flutter SDK 3.47.5**（在 `D:\dev\flutter`），已配好 `Path` 与国内镜像变量
- **Android SDK 36.0.0**，含 `cmdline-tools` / `platform-tools` / `build-tools` / `platforms`
- **Android Studio 2026.1.4**（自带 JDK，不需要另外装 Java）

### 跑起来

工程目录：`D:\dev\today_todo`

> **必须放在纯英文、无空格的路径下**。Flutter 底层的 Gradle / CMake 对含空格或中文的路径支持很差，会报「看不出原因」的编译错误。旧仓库路径 `D:\work buddy\vibe coding` 含空格，所以新工程不在原仓库内。

```
cd /d D:\dev\today_todo
flutter devices      # 确认能认出你的安卓手机
flutter run          # 编译并安装到手机上
```

### 改代码不用重装（热重载）

`flutter run` 跑着的那个终端里按：

| 按键 | 作用 |
| --- | --- |
| `r` | 热重载：改动几秒内出现在手机上，界面状态保留 |
| `R` | 热重启：重新加载整个 App，状态清空 |
| `q` | 退出 |

### 调试设备

**模拟器（当前使用）**——本机已建好 AVD `today_todo_api36`（Android 16 / API 36 / x86_64 / 1080×2400 @ 420 dpi = **411 dp**，落在 PRD AC-19 要求的 360–430 dp 区间内）：

- 双击 `D:\dev\start_emulator.bat` 启动（冷启动约 24 秒进系统）
- `flutter devices` 应能列出 `emulator-5554`
- PRD AC-19 / AC-20 的验收环境本期即为模拟器，真机复核留到后期

**真机（可选）**：

1. 手机上开启「开发者选项」→ 打开「USB 调试」
2. USB 线连到电脑，手机上弹出「允许 USB 调试吗」时点允许
3. `flutter devices` 应能列出你的手机型号

## 项目文件

| 文件 | 说明 |
| --- | --- |
| `lib/main.dart` | Flutter 源码（现为官方示例，阶段 3 将替换为「今日待办」功能） |
| `pubspec.yaml` | Flutter 工程声明与依赖（当前仅 `cupertino_icons`，后续加 sqflite / 通知库） |
| `android/` | 安卓平台工程配置（包名 `com.xingho.today_todo`） |
| `PRD.md` | 产品需求文档：做什么、怎么算做到（含 21 条验收标准） |
| `TECH_DESIGN.md` | 技术设计：选什么技术、数据怎么流转 |
| `research.md` | 竞品调研：为什么这么设计 |
| `AGENTS.md` | 与 AI 协作的规则 |
| `index.html` / `styles.css` / `app.js` | **旧 Web 版，保留作参照**（待 Flutter 版跑通 F1 + F3 后删除，见文末「历史」） |

> 注意：**Flutter 工程不在本仓库内**，它在 `D:\dev\today_todo`；本仓库（含空格路径）作为文档与旧版代码的存放处。

## 数据存在哪

事项数据存在**手机本地的 SQLite 数据库**里（App 私有目录），不上传任何服务器，也没有账号体系。

- 只有这一台手机上有数据，换设备不会带过去 —— 这是本期的明确决定，不是遗漏（见 `PRD.md` 6.2）
- **卸载 App 或清除应用数据，会把事项一起清掉**
- 数据库文件在 App 私有目录里，其它应用读不到

## 当前进度

Flutter 版从零开始写（旧 Web 版的 F1 / F3 不迁移到新工程，见文末「历史」）：

- [x] 阶段 1 环境搭建（Flutter SDK / Android SDK / Android Studio，`flutter doctor` 关键两项通过）
- [x] 阶段 2 创建工程骨架，在模拟器上跑通空壳（`flutter run` + 热重载实测 351 ms）
- [ ] 阶段 3 用实际功能替换工程里的官方示例代码
- [ ] F1 打开即看清要做的事
- [ ] F2 每天固定 1–2 次的清单提醒
- [ ] F3 事项的新增 / 编辑 / 完成 / 删除
- [ ] F4 周期事项（如「每周洗被子」）

## 技术栈

- **Flutter + Dart** —— 界面与全部业务逻辑
- **sqflite（SQLite）** —— 本机数据存储
- **flutter_local_notifications** —— 每日定时提醒（纯本地，不依赖任何服务器）
- **Gradle + AGP** —— 编译打包成可安装的 APK（Android Studio 自带）

选型理由见 `TECH_DESIGN.md` 第二节。

---

## 历史：旧 Web 版（Day 5–7）

本项目最初做的是**纯静态网页**：`index.html` + `styles.css` + `app.js`，数据存浏览器内置的 IndexedDB，用 Python 起本地服务访问。

- **为什么退役**：网页在页面关闭后无法主动推送提醒，而提醒（F2）是核心价值的唯一载体。2026-09-23 决定改用 Flutter 做安卓 App 完全替换。技术上的完整比较见 `TECH_DESIGN.md` 2.2。
- **完成到哪一步**：F1（首页清单）与 F3（新增 / 编辑 / 完成 / 删除）已跑通；F2、F4 未开始。
- **为什么先留着**：它是目前唯一能跑的成品，也是逻辑参照——Flutter 版是**重写**而非搬运，遇到「原来怎么处理的」问题可以直接对照源码。等 Flutter 版跑通 F1 + F3 之后再删。
- **怎么跑旧版**（需要回看时）：

```
cd "D:\work buddy\vibe coding"
py -m http.server 8000
```

然后浏览器打开 **http://localhost:8000**

> 不要直接双击 `index.html` 打开：那样地址栏是 `file://`，IndexedDB 的行为在各浏览器不一致。
