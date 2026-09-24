# macOS Shelf 文件中转应用项目计划

## 1. 项目目标

制作一个常驻 macOS Menu Bar 的文件中转 Shelf。用户可用快捷键呼出悬浮窗口，将 Finder 或其他 App 中的文件拖入，查看文件缩略图和名称，再把文件拖回 Finder/其他 App。Shelf 内容在应用退出后可恢复。

本项目的第一目标是建立“低打扰、低风险、可恢复”的文件中转体验：应用只保存文件引用和展示元数据，不复制或修改原始文件。

## 当前工程基线

- Git 仓库位于 `Shelf/`，当前分支为 `main`，已有初始提交，尚未配置远端。
- Xcode 工程名和 scheme 为 `Shelf`，包含 App、单元测试和 UI 测试 target。
- 当前代码已清理 Xcode 初始 SwiftData 模板；Menu Bar、AppKit 悬浮 Shelf 窗口、设置入口和 Shelf 数据恢复层已实现，文件拖放尚未实现。
- 工程已明确启用 App Sandbox，部署目标统一为 macOS 15.0，应用 Bundle ID 为 `com.rinko.shelf`，Swift 语言模式为 5.0；后续持久化采用 Codable + Application Support，不使用 SwiftData。
- `xcodebuild -list` 能识别工程和 `Shelf` scheme；当前仓库把本机 Xcode `xcuserdata` 纳入了初始提交，Git 清理会移除该跟踪并忽略后续用户数据。

### Phase 1 当前进度

- 已通过 `NSApplicationDelegateAdaptor` 接入 AppKit 生命周期，并将应用设为 accessory activation policy。
- 已实现 `NSStatusItem` 菜单栏入口、Shelf 显示/隐藏、设置入口、清空和退出操作。
- 已实现承载 SwiftUI 内容的浮动 `NSPanel`，支持窗口移动、调整大小、Esc 隐藏和全屏辅助空间行为。
- 已实现 `ShelfItem`、版本化 `ShelfDocument`、`ShelfViewModel` 和 security-scoped bookmark 恢复；数据写入 Application Support，并使用临时文件加原子替换。
- 已加入损坏 JSON 隔离、单 item 解码容错、失效状态恢复、重复 item 保留和不触碰原文件的领域测试。
- 已加入菜单栏、Panel 显示/隐藏和设置入口的 UI 测试骨架；全局快捷键、点击外部隐藏和拖放期间窗口策略留待后续阶段。

## 2. 目标用户流程

```text
用户在 Finder 选中文件
        ↓
拖入 Shelf
        ↓
Shelf 保存文件引用并显示缩略图/文件名
        ↓
用户切换到其他 App
        ↓
从 Shelf 拖出文件
        ↓
目标 App 接收原始文件 URL，Shelf item 保留
```

异常流程：文件被移动、删除或权限变化时，item 不消失，显示为失效状态，用户可以重新定位或手动移除。

## 3. MVP 范围与验收标准

### 3.1 Menu Bar 常驻

验收标准：

- 启动后显示状态栏图标，不要求打开主窗口。
- 菜单至少包含“显示/隐藏 Shelf”“清空 Shelf”“设置”和“退出”。
- 应用退出前不丢失已成功加入的 item。

### 3.2 快捷键呼出 Shelf

验收标准：

- 在其他 App 工作时可以使用全局快捷键显示/隐藏 Shelf。
- 呼出后窗口获得合理焦点并可立即接收拖放。
- 快捷键注册失败或冲突时有可理解的提示，不能静默失效。
- 设置界面展示当前快捷键，并为后续修改预留入口。

### 3.3 悬浮 Shelf 窗口

验收标准：

- Shelf 是独立悬浮窗口，不需要切换到应用主界面才能使用。
- 支持拖动窗口位置，重启后恢复上次位置（若系统允许）。
- 支持 Esc 隐藏；拖放期间不会因普通焦点变化而意外关闭。
- 能适配浅色/深色模式、窗口缩放和不同屏幕。

### 3.4 拖入与展示

验收标准：

- 支持单个或多个文件、文件夹从 Finder 拖入。
- 每个 item 显示缩略图；没有缩略图时显示系统文件图标。
- 显示文件名，长文件名截断但可通过 tooltip 或辅助方式查看完整名称。
- 支持中文、空格、emoji 和特殊字符文件名。
- 拖入后 item 顺序稳定，并能显示加入状态或失败原因。

### 3.5 拖出

验收标准：

- 可以将单个或多个 item 拖到 Finder 和至少一个其他文件拖放目标。
- 目标接收到原始文件 URL，不产生额外内容副本。
- 取消拖放不会删除或改变 item。
- 拖出成功后 item 默认保留，便于重复使用。

### 3.6 删除

验收标准：

- 每个 item 可单独删除。
- 支持清空 Shelf，并对批量删除提供确认或撤销。
- 任何删除操作都不会删除原文件。
- 删除后立即更新界面并持久化。

### 3.7 退出后恢复

验收标准：

- 退出并重新启动后，item 顺序、文件名和引用能够恢复。
- 恢复时重新解析安全书签并刷新文件状态。
- 文件已移动、重命名、删除或权限不足时，item 仍然显示并标注失效。
- 持久化文件损坏时，应用不崩溃，并给出可恢复的错误处理。

## 4. 建议技术方案

### 4.1 工程结构

建议建立一个 macOS App 工程，采用 SwiftUI + AppKit 混合架构：

- SwiftUI：Shelf 列表/网格、item 卡片、空状态、设置页面。
- AppKit：`NSStatusItem`、`NSPanel`、窗口层级、系统拖放桥接、应用生命周期。
- `QLThumbnailGenerator`：异步生成文件缩略图。
- `NSWorkspace`：文件图标、文件名和基础文件信息。
- Codable + Application Support：持久化 Shelf item 元数据。
- security-scoped bookmark：支持沙盒环境下应用重启后的文件引用访问。

### 4.2 核心数据模型

建议的 `ShelfItem` 字段：

```swift
struct ShelfItem: Identifiable, Codable, Equatable {
    let id: UUID
    var bookmarkData: Data?
    var fallbackURLString: String?
    var displayName: String
    var contentTypeIdentifier: String?
    var addedAt: Date
    var position: Int
    var status: ShelfItemStatus
}
```

`ShelfItemStatus` 至少覆盖：正常、正在解析、文件不存在、无权限、书签失效、未知错误。模型必须携带版本号，便于后续迁移。

### 4.3 持久化策略

- 数据目录：`Application Support/<bundle identifier>/`。
- 元数据文件：建议 `shelf-items.json`，后续可迁移到数据库。
- 采用写临时文件后原子替换。
- item 添加、删除、排序变化后立即异步保存；退出回调只做补充保存。
- 不保存文件二进制内容、不生成用户文件副本。
- 启动恢复流程必须容忍单个 item 解析失败，不因一个坏 item 丢失全部 Shelf。

## 5. 分阶段实施计划

### Phase 0：工程初始化与风险验证

产出：

- 创建 macOS App 工程和最低系统版本。
- 验证 Menu Bar 状态项、`NSPanel` 悬浮窗口、SwiftUI 容器。
- 验证 Finder 文件拖入和从 Shelf 拖出最小闭环。
- 验证安全书签在沙盒和重启场景下的可用性。
- 记录快捷键实现方案及许可证/依赖选择。

完成标志：可以启动一个空 Shelf，拖入一个文件并在日志中拿到可恢复引用。

### Phase 1：Menu Bar、窗口和快捷键

产出：

- Menu Bar 图标及基础菜单。
- Shelf `NSPanel` 创建、显示、隐藏和窗口位置管理。
- 快捷键注册、冲突/失败提示和基础设置入口。
- Esc 隐藏、点击外部隐藏策略和多显示器基础处理。

完成标志：在 Finder 和其他 App 中均可通过菜单/快捷键稳定呼出和隐藏 Shelf。

### Phase 2：Shelf 状态与拖入

当前进度：Shelf 状态模型、单一 ViewModel、Application Support 原子持久化和 bookmark 恢复已完成；拖入和拖出仍待后续阶段。

产出：

- `ShelfViewModel` 与 `ShelfItem` 数据模型。
- 支持批量拖入文件和文件夹。
- item 顺序、唯一 ID、重复 item 处理。
- security-scoped bookmark 创建与存储。
- 原子持久化和启动恢复骨架。

完成标志：拖入的文件列表稳定显示，重启后能恢复，删除原文件后 item 不会静默消失。

### Phase 3：缩略图与完整 UI

产出：

- Quick Look 缩略图异步生成、缓存和取消。
- 无缩略图时的系统图标降级。
- 文件名排版、tooltip、失效状态、空状态和加载状态。
- 浅色/深色模式、辅助功能标签和键盘操作。

完成标志：常见文件类型和异常文件状态下，Shelf 视觉反馈清晰且无明显卡顿。

### Phase 4：拖出与删除

产出：

- 单 item 和多 item 文件拖出。
- Finder 及其他文件拖放目标验证。
- 单项删除、清空、撤销/确认策略。
- 确保拖出和删除不影响原始文件。

完成标志：完成“Finder → Shelf → Finder/其他 App”的完整主流程，并覆盖取消拖放。

### Phase 5：可靠性、测试与发布准备

产出：

- 单元测试、集成/UI 测试和关键手工验收清单。
- 文件移动/重命名/删除/权限变化测试。
- 崩溃恢复、损坏数据恢复和并发保存测试。
- 签名、公证、沙盒权限、登录启动（如启用）检查。
- README、设置说明、隐私说明和已知限制。

完成标志：在干净环境安装后，核心流程和恢复流程可重复通过。

## 6. 测试矩阵

| 场景 | 预期结果 |
| --- | --- |
| Finder 拖入一个普通文件 | 创建 1 个 item，显示名称和图标/缩略图 |
| Finder 拖入多个文件 | 按拖入顺序创建多个 item |
| 拖入文件夹 | 文件夹作为 1 个 item，不扫描内容 |
| 重复拖入同一文件 | 默认保留两个独立 item |
| 从 Shelf 拖到 Finder | Finder 接收原始文件 URL，Shelf item 保留 |
| 拖出后取消 | Shelf 无变化 |
| 删除 Shelf item | 只删除 Shelf 元数据，不删除源文件 |
| 退出并重新启动 | item、顺序和状态恢复 |
| 文件移动/重命名 | 重新解析书签；若不可定位则显示失效 |
| 文件删除 | item 保留并显示文件不存在 |
| 无缩略图文件 | 使用系统图标，不阻塞主界面 |
| 中文/emoji 文件名 | 正确显示并可拖出 |
| 快捷键被占用 | 给出提示，Menu Bar 菜单仍可用 |
| 持久化文件损坏 | 应用不崩溃，进入可恢复的空/部分恢复状态 |

## 7. 风险与决策

### 全局快捷键依赖

不同实现对沙盒、辅助功能权限和系统版本的兼容性不同。Phase 0 先验证方案，必须保留 Menu Bar 菜单作为无快捷键时的可用后备入口。

### 文件引用与沙盒

只保存普通 URL 可能无法在重启后访问文件。正式方案应优先保存 security-scoped bookmark，并在使用后正确释放访问范围；不能把“路径字符串存在”误认为“文件可访问”。

### 文件移动与重命名

书签不保证所有外部变更都能无条件定位。UI 需要明确区分“暂时不可访问”“文件已不存在”和“书签无法解析”，后续可增加“重新选择文件”。

### 缩略图性能

大文件和大量 item 可能让 Quick Look 生成变慢。缩略图服务应限制并发、缓存结果、支持取消，并避免在主线程读取文件内容。

### 拖放兼容性

不同目标 App 接收的 pasteboard 类型可能不同。先保证 Finder 闭环，再用文本编辑器、邮件/聊天类 App 和其他常见目标验证兼容性，并保留明确的失败反馈。

## 8. 后续可选功能

以下功能不应阻塞 MVP：

- Shelf item 拖动排序和置顶。
- 多个 Shelf 或命名 Shelf。
- 自动隐藏、固定窗口和位置/尺寸设置。
- “拖出成功后移除”偏好。
- 右键菜单：在 Finder 中显示、复制路径、重新定位、移除。
- 搜索、分组和最近使用记录。
- 登录启动和菜单栏图标状态自定义。

## 9. MVP 发布前检查

- [ ] 核心流程：Finder → Shelf → Finder/其他 App 可用。
- [ ] Menu Bar 常驻和菜单操作可用。
- [ ] 快捷键呼出/隐藏可用，失败时有后备入口。
- [ ] 缩略图、系统图标、长文件名和失效状态均有合理表现。
- [ ] 删除与清空不会触碰原始文件。
- [ ] 退出/重启恢复通过。
- [ ] 文件移动、删除和权限变化有可理解反馈。
- [ ] 持久化采用原子写入并有版本号。
- [ ] 通过浅色/深色模式、辅助功能和多显示器基础检查。
- [ ] 完成签名、公证和干净安装验证。
