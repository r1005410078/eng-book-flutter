# 变更：重构课程资源交付协议（大包稳定下载）

## 为什么
当前大课程包在不稳定网络或低内存环境下容易下载失败。现有模型默认单一 ZIP URL，未为 Flutter 提供一等公民的分片交付协议。

## 变更内容
- 为 Flutter 下载中心引入统一课程资源协议 `asset`。
- 定义两种交付模式：
  - `zip`：小文件直接下载并解压。
  - `segmented_zip`：通过 manifest 下载分片，按顺序合并后再解压。
- 在分片模式下强制双层完整性校验：
  - 分片级 SHA-256 校验。
  - 最终合并 ZIP 的 SHA-256 校验。
- 在发布侧定义阈值策略：
  - 小文件发布为 `zip`。
  - 大文件发布为 `segmented_zip` + manifest。
- 本次为协议重构，不要求向旧字段兼容。

## 影响范围
- 受影响 spec：`course-package`
- 受影响代码：
  - `tools/course_pipeline/course_pipeline_ops.py`（发布协议输出）
  - `lib/src/features/download_center/data/preset_catalog_loader_io.dart`（目录协议解析）
  - `lib/src/features/download_center/data/download_center_repository_io.dart`（下载/合并/校验/安装）
  - `lib/src/features/download_center/domain/download_models.dart`（分片下载进度状态）
