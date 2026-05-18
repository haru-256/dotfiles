# Cursor-Based Pagination Helper

## Goal
Provide a reusable cursor-based pagination helper so list endpoints can paginate
over stable, opaque cursors instead of offset/limit, avoiding skipped or
duplicated rows when the underlying dataset changes between requests.

## Non-Goals
- Offset/limit pagination retrofitting of existing endpoints.
- Changing any public API response envelope beyond adding cursor fields.
- Persisting cursor state server-side (cursors remain stateless/opaque).

## Acceptance Criteria
1. Cursor encoding is opaque, stable, and round-trips deterministically.
2. Forward pagination returns each row exactly once with no skips/duplicates
   under concurrent inserts.
3. Helper is dependency-light and unit-tested.

## Approach
- Encode the sort key + tiebreaker into a base64url opaque cursor.
- Decode + validate cursors defensively; reject malformed cursors.
- Expose a small helper API consumed by list endpoints.

## Test Plan
- Unit tests for encode/decode round-trip and stability.
- Tests for malformed/empty cursor handling.
- Tests for forward traversal correctness across page boundaries.

---

## Implementation Log
<!-- Implementer appends one line per attempt: [YYYY-MM-DD] attempt #N -> STATUS | commit-or-failure-signature -->

## Review Findings
<!-- This template is also defined in prompts/planner_v2.md. Keep them in sync on every edit. -->

### Reviewer Raw Findings
<!-- Planner V2 copies @reviewer_v2's structured findings verbatim here when invoking @reviewer_v2
     during a workflow. Direct /review-*-v2 calls do not write here.
     Raw findings are review input (audit history), not implementation instructions. -->
[2026-05-16] implementation -> APPROVE | no findings

### Planner V2 Adjudication
<!-- Planner V2 appends adjudication tables for v2 workflow reviews.
     Only ACCEPT rows are implementation instructions:
     | ID | Severity | Decision | Reason | Action | -->

## Deviations from Plan
<!-- Implementer documents intentional deviations and reasons -->

## Open Questions
<!-- Any agent adds questions for planner_v2 or arbiter_v2 -->
