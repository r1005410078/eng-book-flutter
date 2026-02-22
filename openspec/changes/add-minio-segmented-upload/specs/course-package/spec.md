## ADDED Requirements

### Requirement: 分卷上传大课程包到 MinIO (Segmented MinIO Upload For Large Packages)

The system MUST support segmented object upload for large course package files and emit a machine-readable manifest.

#### Scenario: 按固定分片顺序上传
- **WHEN** 用户执行 `package upload-minio-segmented <file>`
- **THEN** 系统必须按配置的分片大小顺序上传多个对象
- **AND** 分片对象键必须稳定可预测（含顺序编号）

#### Scenario: 生成并发布分片清单
- **WHEN** 分片上传成功
- **THEN** 系统必须生成包含源文件校验值、分片数量、分片对象键与 URL 的 manifest JSON
- **AND** 默认必须将 manifest 上传到目标 bucket

#### Scenario: 返回结构化结果
- **WHEN** 命令执行完成
- **THEN** 系统必须输出结构化 JSON，包含分片数量、已上传字节数、manifest 本地路径与（如启用）manifest 对象路径

#### Scenario: 按 manifest 下载并还原
- **WHEN** 用户执行 `package download-minio-segmented` 并提供 manifest（本地文件或对象键）
- **THEN** 系统必须按 manifest 的分片顺序下载并合并为单一文件
- **AND** 必须校验还原文件大小与 sha256（若 manifest 提供）并在不匹配时返回失败
