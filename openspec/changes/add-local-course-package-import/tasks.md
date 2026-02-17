## 1. Spec 与 Schema（先定义契约）
- [x] 1.1 定义原始输入目录命名规则（编号主键匹配媒体与附属文件）。
- [x] 1.2 定义 `course_manifest.json` 与 `lesson.json` 的最小可用 schema。
- [x] 1.3 定义句子级必填字段与可选字段（含 `grammar` 与 `usage`）。
- [x] 1.4 定义任务状态机与错误码（`uploaded/processing/paused/ready/failed/stopped`）。
- [x] 1.5 定义 Human-in-the-loop 步骤：`task run-step <task_id> translate|grammar|summary` 的触发与状态回写。

## 2. 任务控制命令（先搭控制面）
- [x] 2.1 为命令输出定义稳定 JSON 响应格式。
- [x] 2.2 落盘任务状态文件 `.runtime/tasks/<task_id>.json` 与事件日志 `.runtime/tasks/events.log`。
- [x] 2.3 提供 `course add <folder_path>` 与 `course delete <course_id>`。
- [x] 2.4 提供 `task pause/resume/stop/retry/delete <task_id>`。
- [x] 2.5 提供 `task get <task_id>` 与 `task list [--status ...]`。
- [x] 2.6 提供 `task watch <task_id>`，在任务完成或失败时触发本地通知。
- [x] 2.7 提供全局命令 `course-pipeline`（wrapper/symlink），并保证其仅转发到 `tools/course_pipeline/course_pipeline_ops.py`。
- [x] 2.8 更新 skill 调用方式为优先使用全局命令，禁止在 skill 中复制项目业务脚本实现。
- [x] 2.9 规定技能与脚本位置：`~/.codex/skills/course-pipeline-ops` 编排、仓库 `tools/course_pipeline` 执行。

## 3. 本地处理流水线（在控制面上填能力）
- [x] 3.1 实现 raw 目录扫描与课程任务创建。
- [x] 3.2 实现 ffmpeg 预处理（音轨提取、时长探测、媒体标准化）。
- [x] 3.3 实现英文字幕生成与时间轴对齐（优先复用用户已提供字幕）。
- [x] 3.4 实现中英翻译、句子级语法解析与使用场景提取。
- [x] 3.5 实现课程打包输出（标准目录结构 + JSON + 字幕 + 状态报告）。

## 4. 质量保障（先有样例再接 UI）
- [x] 4.1 添加 schema 校验与命名匹配单元测试。
- [x] 4.2 添加最小样例课程夹具（仅媒体输入）与完整样例夹具（含字幕/md）。
- [x] 4.3 添加端到端脚本测试：从 raw 输入到 package 输出可用。
- [x] 4.4 添加命令暴露校验：验证 `course-pipeline --help` 可用且输出与项目脚本一致。

## 5. Flutter 集成（最后接入消费侧）
- [x] 5.1 实现 `course_manifest.json` 加载与课时索引读取。
- [x] 5.2 对缺失资源提供降级展示与错误提示。
- [x] 5.3 将句子级 `grammar/usage` 接入练习阅读页面展示。
