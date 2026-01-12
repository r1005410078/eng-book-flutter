# 规格：数据 Mock

## MODIFIED Requirements

### Requirement: 多句子数据结构

系统必须 (MUST) 提供包含多条连续句子的 Mock 数据，用于模拟完整的视频练习场景。

#### Scenario: 句子列表结构

- **Given** 不需要特定条件
- **Then** `mockSentences` 应为一个 `List<SentenceDetail>`
- **And** 列表至少包含 3-5 条句子
- **And** 每条句子应有连续的时间戳（例如 0-5s, 5-10s, 10-18s...）
