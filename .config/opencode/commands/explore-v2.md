---
description: Read-only deep repository exploration through v2 explorer
agent: explorer_v2
---

Explore the following question or scope:
$ARGUMENTS

Rules:
- Use progressive deepening (discovery -> structural -> behavioral pass).
- Avoid generated files, lock files, vendored deps.
- Output: Summary Report (under 1500 tokens) + Exploration Log when useful.
- If more context is needed, return a request for a narrower follow-up.
