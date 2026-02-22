# 变更：AI 翻译步骤 Token 优化

## 为什么 (Why)
当前的 `course_pipeline_ops.py` 在执行 `translate` 步骤时，对每个句子进行独立的 AI 翻译调用。这种“原子化”的请求方式导致了大量的 Prompt Overhead，显著增加了 AI 服务（如 Codex 或 Google Translate）的 Token 消耗和处理时间，尤其是在处理包含大量短句的课程时。这不仅增加了成本，也降低了流水线的效率。

## 变更内容 (What Changes)
- **引入批量翻译机制**: 修改 `translate_en_to_zh_codex` 函数，使其能够接受一个英文句子列表，并一次性返回对应的中文译文列表。这将显著减少与 AI 服务的交互次数。
- **优化 `execute_step_translate`**: 更新 `execute_step_translate` 步骤，在处理每个课时时，收集所有待翻译的英文句子，然后进行批量翻译。
- **增强持久化缓存**: 确保现有的翻译缓存机制能够与批量翻译协同工作，优先从缓存中获取译文，只有未缓存的句子才进行批量 AI 调用。

## 影响范围 (Impact)
- Affected specs: `course-package` (specifically `本地 AI 解析流水线`)
- Affected code:
  - `tools/course_pipeline/course_pipeline_ops.py` (主要修改 `translate_en_to_zh_codex` 和 `execute_step_translate` 函数)
