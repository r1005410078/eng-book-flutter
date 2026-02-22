## 1. 规范与数据契约
- [x] 1.1 定义新的目录资源契约：`asset.mode`（`zip` / `segmented_zip`）。
- [x] 1.2 定义 Flutter 所需的分片 manifest 字段：`source_size_bytes`、`source_sha256`、`parts[index/object_key/size_bytes/sha256/url]`。
- [x] 1.3 定义发布侧阈值策略与模式选择规则。

## 2. 发布侧 / Pipeline
- [x] 2.1 更新发布输出，仅产出新 `asset` 协议（不输出旧兼容字段）。
- [x] 2.2 实现阈值路由：小包走单 ZIP，大包走分片+manifest。
- [x] 2.3 为两种模式补齐校验元数据生成。

## 3. Flutter 下载中心
- [x] 3.1 重构课程目录解析到新 `asset` 协议。
- [x] 3.2 实现 `zip` 模式流程：直链下载 -> SHA-256 校验 -> 安装。
- [x] 3.3 实现 `segmented_zip` 模式流程：下载 manifest -> 分片断点续传 -> 分片 SHA-256 校验 -> 顺序合并 -> 最终 SHA-256 校验 -> 安装。
- [x] 3.4 持久化分片进度状态（`current_part_index`、`current_part_downloaded_bytes`），支持暂停恢复。
- [x] 3.5 统一下载进度口径为总字节进度。

## 4. 验证
- [x] 4.1 增加目录解析与协议分发测试。
- [x] 4.2 增加分片顺序合并与哈希不一致失败路径测试。
- [x] 4.3 增加分片中断恢复测试。
- [x] 4.4 运行 `flutter test` 覆盖下载中心与课程包加载集成路径。
