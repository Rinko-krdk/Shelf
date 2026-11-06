Shelf 1.0 preview.4 — Apple Silicon / macOS 15+

这是未公证测试版，不是正式发布版。使用本地 ad-hoc 签名，没有 Developer ID。
This preview is ad-hoc signed, without Developer ID or Apple notarization.

安装 / Install
解压后将 Shelf.app 拖入“应用程序”，双击启动。Shelf 在菜单栏运行，没有 Dock 图标。
Extract the ZIP, drag Shelf.app into Applications, then open it. Shelf runs in the menu bar, without a Dock icon.

macOS 可能阻止打开未公证的应用。确认下载来源后，可按照 Apple 的说明，在尝试打开后到“系统设置 → 隐私与安全性”查看是否有“仍要打开”选项。该选项可能受系统或设备管理策略限制。
macOS may block this unnotarized preview. If you trust the source, follow Apple's instructions to review the Open Anyway option in System Settings → Privacy & Security after attempting to open the app. Availability depends on macOS and device policy.
https://support.apple.com/102445

使用 / Usage
从 Finder 拖入文件，拖动时左右摇动鼠标可唤出 Shelf；也可使用菜单栏或 Control-Option-Space。
Drag files from Finder into Shelf; shake the pointer left/right while dragging to summon Shelf, or use the menu bar or Control-Option-Space.

Shelf 保存文件引用，不保存文件副本。拖出成功写入目标位置后会尝试删除源文件；删除失败时保留 Shelf 条目，目标位置可能已有副本。取消或写入失败会保留源文件。
Shelf holds references, not copies. After a drag-out successfully writes the destination, Shelf attempts to delete the source. If deletion fails, the item stays in Shelf and a destination copy may already exist. Cancellation or a failed write preserves the source.

移除条目、清空或隐藏 Shelf 不会删除源文件。隐藏或重新启动会清空临时条目。
Removing items, clearing, or hiding Shelf does not delete sources. Hiding or restarting clears temporary references.

测试请使用可丢弃文件。首次安装和升级时先退出正在运行的 Shelf。
Use disposable files for testing. Quit any running Shelf before installing or replacing it.

设置 / Settings
可选择“登录时启动”（默认不主动注册），或关闭鼠标摇动手势；关闭摇动后仍可使用菜单栏和快捷键。设置中显示版本、构建号、© 2026 Rinko，并提供反馈入口。
Settings offer native Launch at Login (no automatic registration), a mouse-shake gesture toggle, version/build, © 2026 Rinko, and a feedback link. Menu and shortcut activation remain available with shake disabled.

若登录时启动显示等待批准，请在设置中打开 macOS 的登录项设置。当前 ad-hoc 签名包的真实注册与注销后重新登录仍需验收；系统拒绝注册时会显示原因。
If login startup awaits approval, use the settings link to macOS Login Items. Real registration and logout/login behavior with this ad-hoc signed preview still require acceptance; registration errors are shown inline.

限制 / Limitations
- 仅 Apple Silicon；Intel 未支持或验收。Apple Silicon only; Intel is not supported or validated.
- VoiceOver 朗读尚未验收。VoiceOver speech has not been validated.
- 本 preview.4 的安装、登录启动、升级及下载后首次启动仍需验收。Installation, native login startup, upgrades, and first launch after browser download still need acceptance for preview.4.

隐私 / Privacy
Shelf 不上传文件内容，仅在本机保存临时书签和基本元数据，用于显示和文件操作。
Shelf does not upload file contents. It keeps temporary bookmarks and basic metadata locally for display and file operations.

许可证与源码 / License and source
Shelf 以 GPL-3.0-only 许可发布；许可证全文见随附的 LICENSE。对应源码可从同一 Release 页面下载：
Shelf is licensed under GPL-3.0-only; see the included LICENSE. Download the corresponding source from the same Release page:
https://github.com/Rinko-krdk/Shelf/releases/tag/v1.0-preview.4

反馈 / Feedback
https://github.com/Rinko-krdk/Shelf/issues
请附 macOS 版本、复现步骤和错误提示；不要上传私人文件。
Include macOS version, steps to reproduce, and error text. Do not upload private files.
