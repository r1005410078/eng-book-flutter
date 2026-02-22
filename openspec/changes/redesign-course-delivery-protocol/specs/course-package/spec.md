## ADDED Requirements

### Requirement: 课程资源交付协议 (Course Asset Delivery Protocol)
系统 MUST 使用统一 `asset` 契约发布每门可下载课程，并明确交付模式与完整性元数据。

#### Scenario: 小文件使用单 ZIP 模式
- **WHEN** 发布产物大小小于等于配置阈值
- **THEN** 发布数据必须标记 `asset.mode = "zip"`
- **AND** 必须提供 `asset.url`、`asset.size_bytes`、`asset.sha256`

#### Scenario: 大文件使用分片 ZIP 模式
- **WHEN** 发布产物大小大于配置阈值
- **THEN** 发布数据必须标记 `asset.mode = "segmented_zip"`
- **AND** 必须提供 `asset.manifest_url`、`asset.size_bytes`、`asset.sha256`

### Requirement: 分片清单契约 (Segmented Manifest Contract)
系统 MUST 为分片课程资源提供机器可读 manifest。

#### Scenario: 清单包含还原必需字段
- **WHEN** 客户端获取分片清单
- **THEN** 清单必须包含 `source_size_bytes` 与 `source_sha256`
- **AND** 清单必须包含有序 `parts` 列表，且每项至少包含 `index`、`object_key`、`size_bytes`、`sha256`、`url`

### Requirement: Flutter 分片下载与合并 (Flutter Segmented Download And Merge)
Flutter MUST 支持分片课程下载、顺序合并与安装。

#### Scenario: 分片下载并顺序合并
- **WHEN** `asset.mode = "segmented_zip"`
- **THEN** Flutter 必须按清单顺序下载各分片并合并为单一 ZIP 文件
- **AND** 合并成功后必须进入安装流程

#### Scenario: 暂停恢复从分片进度继续
- **WHEN** 用户暂停后恢复分片下载任务
- **THEN** Flutter 必须从已记录的 `current_part_index` 与分片内偏移继续下载
- **AND** 不得重复下载已完成且校验通过的分片

### Requirement: 完整性校验策略 (Integrity Verification Strategy)
系统 MUST 在安装前强制执行完整性校验。

#### Scenario: 分片级校验
- **WHEN** 单个分片下载完成
- **THEN** Flutter 必须校验该分片 SHA-256
- **AND** 校验失败时仅重试该分片

#### Scenario: 最终文件校验
- **WHEN** 所有分片合并完成或单 ZIP 下载完成
- **THEN** Flutter 必须校验最终 ZIP 的 SHA-256 与发布元数据一致
- **AND** 校验失败时必须阻止安装并返回失败状态
