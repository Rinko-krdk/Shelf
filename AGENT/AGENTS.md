# AGENTS.md

## 项目概述

这是一个运行在 macOS 上的文件 Shelf（临时中转架）应用。应用常驻 Menu Bar，用户可以通过全局快捷键呼出悬浮 Shelf，把 Finder 或其他 App 中的文件拖入 Shelf 暂存，再从 Shelf 将文件拖回 Finder 或其他支持文件拖放的 App。

核心体验：Shelf 应该像一个轻量、可靠、可恢复的“文件中转站”。用户把文件拖出并由目标成功接收时，Shelf 执行剪切：删除原文件并从 Shelf 移除该 item；取消拖放或传输失败时保留原文件和 Shelf item。退出应用后仍能恢复 Shelf 内容。

## 产品边界

### 必须支持

1. Menu Bar 常驻，并提供显示/隐藏 Shelf、清空 Shelf、退出应用等入口。
2. 全局快捷键呼出或隐藏 Shelf；快捷键应可配置，默认值在实现阶段确定并在设置中展示。
3. Shelf 使用悬浮窗口，不抢占普通文档窗口的工作流。
4. 从 Finder 拖入文件、文件夹及可被系统识别的 URL 文件引用。
5. 展示文件缩略图、文件名；缩略图不可用时显示稳定的文件类型图标。
6. 从 Shelf 拖出到 Finder 或其他支持文件拖放的 App。
7. 删除单个 Shelf item，并提供清空 Shelf 的操作。
8. 应用退出、崩溃后重启或 macOS 重新登录后，恢复上次保存的 Shelf 内容。
9. 同一文件可以重复加入 Shelf；每个 item 的顺序必须稳定。
10. 文件已移动、重命名或不可访问时，Shelf 仍应保留该 item，并明确显示失效状态。

### 暂不包含

- 将文件内容复制到应用私有目录或云端。
- 自动上传、同步、版本控制或文件内容编辑。
- 复杂的文件预览编辑器。
- 为了拖出而修改原文件权限。
- 除用户主动拖出并成功完成的剪切操作外，不删除或改写原文件。

## 技术基线

- 平台目标：macOS 15.0+；工程 App、单元测试和 UI 测试 target 统一使用 macOS 15.0。
- 语言：使用当前 Xcode 的 Swift 编译器，工程语言模式保持 Swift 5.0。
- UI：SwiftUI 负责 Shelf 内容和设置界面，AppKit 负责 Menu Bar、NSPanel/悬浮窗口、拖放桥接和系统级交互。
- 持久化：Shelf item 优先使用 Codable + Application Support 下的 JSON 元数据；不要保存文件内容副本。当前工程已移除 Xcode 模板中的 SwiftData 示例，除非后续重新评估，否则不引入 SwiftData/Core Data。
- 文件引用：优先保存可安全解析的书签数据（security-scoped bookmark），同时保存展示所需的 URL、文件名和类型元数据。
- 缩略图：使用 Quick Look Thumbnailing（`QLThumbnailGenerator`），并提供 NSWorkspace 图标作为降级方案。
- 全局快捷键：不要自行轮询键盘事件。优先采用稳定的系统级快捷键方案，并将注册失败、冲突和权限状态反馈给用户。
- 测试：Swift Testing 或 XCTest；UI 测试覆盖拖放、窗口显示/隐藏、删除和重启恢复。

## 推荐模块划分

```text
App/
  ShelfApp.swift                       # SwiftUI 应用入口
  AppDelegate.swift                    # 生命周期与依赖组装

Domain/
  ShelfItem.swift                      # Shelf item、状态与持久化文档模型

State/
  ShelfViewModel.swift                 # Shelf 状态、用户操作与持久化协调

Services/
  ShelfFileService.swift               # 文件元数据、security-scoped bookmark 与源文件操作
  ShelfPersistenceService.swift        # Application Support JSON 原子持久化
  ShortcutService.swift                # 可配置全局快捷键
  ThumbnailService.swift               # Quick Look 缩略图缓存与取消

Features/Shelf/
  ShelfPanelController.swift           # NSPanel 创建、显示与隐藏
  ShelfView.swift                      # Shelf 网格、文件拖入与多选
  ShelfItemCard.swift                  # 缩略图、名称、状态和移除操作
  ShelfDropImporter.swift              # 文件 URL 拖入解析
  ShelfDragSourceView.swift            # AppKit 文件 Promise 拖出桥接
  ShelfFilePromiseDelegate.swift       # 文件传输与结果回报

Features/MenuBar/
  MenuBarController.swift      # 状态栏图标及菜单

Features/Settings/
  SettingsView.swift                   # 全局快捷键展示和录制
  SettingsWindowController.swift       # 设置窗口
```

模块职责可随实现演进，但应保持领域逻辑、系统桥接和 UI 解耦。

## 关键行为约定

### Shelf item 生命周期

1. 文件拖入后先校验 URL 类型和可访问性。
2. 创建 `ShelfItem`，生成稳定 ID，保存原始 URL、展示名、UTI/类型、添加时间和顺序。
3. 能生成安全书签时保存书签数据；无法生成时保留可用的非持久化 URL，并将恢复能力标记为受限。
4. 更新内存状态后立即异步持久化，避免应用异常退出导致刚加入的 item 丢失。
5. 手动删除 item 只删除 Shelf 元数据与书签，不删除原始文件。
6. 用户主动拖出 item 后，只有目标确认接收且剪切传输完成时才删除原文件并移除 Shelf item；取消或失败时保留两者。

### 文件拖入

- 接受 `public.file-url`，必要时兼容 `public.url` 和 Finder 常见拖放数据。
- 支持多文件批量拖入，并保持拖入顺序。
- 拖入目录时按一个 item 处理，不扫描目录内容。
- 重复文件不去重，除非产品需求后续明确改为去重；重复 item 便于用户表达不同的工作顺序。
- 对无法访问、已删除或不支持的对象，不崩溃，不静默丢弃；通过 item 状态或轻量错误提示说明原因。

### 文件拖出

- 拖出采用剪切语义，通过文件 Promise 向目标提供文件；不在应用内长期保存文件内容副本。
- 多选拖出时保持 Shelf 顺序，并逐项处理传输结果。
- 只有目标成功接收且文件传输完成后，才删除源文件并移除对应 Shelf item。
- 取消拖放、目标拒绝或传输失败时，保留源文件和对应 Shelf item，并向用户说明失败项。
- 若现有书签没有源文件删除所需的授权，应先让用户重新选择同一文件并取得相应授权；校验失败或用户取消时不得执行剪切。

### 悬浮窗口

- 使用适合悬浮工具窗口的 `NSPanel` 配置，避免成为普通 App 窗口或长期出现在 Dock/Command-Tab 中，除非用户设置要求显示主窗口。
- 默认保持在普通窗口之上，但不覆盖全屏空间或系统安全界面。
- 呼出时优先聚焦并定位到上次位置；隐藏时不改变当前 App 的文件选择状态。
- 窗口应支持 Esc 隐藏、点击外部隐藏（如不影响拖放），并保留明确的固定/自动隐藏策略。
- 不在拖放过程中自动关闭 Shelf。

### 持久化与恢复

- 数据文件放在 `Application Support/<bundle identifier>/`，不要写入项目目录。
- 保存过程使用临时文件 + 原子替换，避免损坏已有数据。
- 恢复时逐项解析书签并刷新失效状态；不能解析的 item 仍显示文件名和失效提示。
- 数据模型要支持版本号与迁移，未来新增字段必须有默认值。
- 应用退出时可以补充同步保存，但不能只依赖退出回调。

## 安全与隐私

- 不上传或编辑用户文件；唯一的删除场景是用户主动拖出并由目标成功接收后完成剪切。
- 不因拖入、应用退出、Shelf 清空或手动移除 item 而删除源文件。
- 文件访问遵循 macOS 沙盒规则；如果启用 App Sandbox，应配置用户选择文件的读权限和持久化书签能力。
- 不申请与功能无关的权限。
- 日志不得记录完整文件内容；路径日志只用于调试，正式构建应避免泄露敏感路径。
- 遇到书签解析失败、权限变化或文件丢失时，给出可理解的恢复动作，例如“重新选择文件”或“从 Shelf 移除”。

## 代码与交互规范

- 使用清晰的 Swift 命名、较小的类型和单一职责；避免把 AppKit 窗口控制、持久化和业务状态塞进 View。
- UI 状态由单一 `ShelfViewModel` 驱动；不要在多个 View 中各自维护同一份 item 数组。
- 异步缩略图加载必须支持取消、缓存和主线程 UI 更新。
- 所有用户可见字符串集中管理，默认使用简体中文，同时预留本地化结构。
- 图标、颜色和间距优先使用系统语义值，适配浅色/深色模式和辅助功能字体大小。
- 清空和手动移除 Shelf item 应二次确认，且不删除源文件。剪切拖出会删除源文件，界面必须明确显示剪切语义；剪切只可在用户主动拖出且目标成功接收后完成。
- 任何新增第三方依赖都要说明用途、许可证、维护状态和对沙盒/签名的影响。

## 测试要求

提交前至少验证：

- 单文件、多文件、文件夹拖入。
- 文件名包含空格、中文、emoji 和特殊字符。
- 普通文件、图片、视频、PDF、无缩略图文件和目录的展示。
- 从 Shelf 拖到 Finder、文本编辑器或其他可接受文件拖放的 App。
- 成功剪切后确认目标文件存在、源文件和 Shelf item 已移除；取消或失败时确认源文件和 Shelf item 均保留。
- 删除单项、清空、剪切授权取消/失败、重复 item。
- 退出并重新启动后恢复顺序、名称、缩略图和失效状态。
- 文件被移动、重命名、删除或权限变化后的表现。
- 快捷键呼出/隐藏、快捷键冲突、窗口层级、浅色/深色模式和不同显示器布局。
- 快速连续添加/删除时的数据一致性，以及应用异常终止后数据文件可恢复性。

## 每次改动的完成标准

- 先确认改动影响的模块和持久化兼容性。
- 为领域逻辑补充单元测试；为窗口、拖放和恢复流程补充 UI/集成测试或手工验证记录。
- 运行格式化、构建和相关测试，并记录无法执行的检查及原因。
- 不提交构建产物、用户数据、完整文件副本或临时调试日志。
- 改动涉及用户行为时，同步更新 `AGENT/PROJECT_PLAN.md` 或产品说明。
