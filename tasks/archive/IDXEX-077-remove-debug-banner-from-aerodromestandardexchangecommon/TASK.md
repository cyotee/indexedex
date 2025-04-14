# Task IDXEX-077: Remove Debug Banner from AerodromeStandardExchangeCommon

**Repo:** IndexedEx
**Status:** Ready
**Created:** 2026-02-10
**Dependencies:** IDXEX-043
**Worktree:** `feature/IDXEX-077-remove-debug-banner-from-aerodromestandardexchangecommon`

---

## Description

Remove the debug banner rendering and any dev-only logging from
`AerodromeStandardExchangeCommon` so production builds do not include
development UI/text or extraneous console output.

## Dependencies

- IDXEX-043: Aerodrome standard exchange improvements

## User Stories

### US-IDXEX-077.1: Remove debug banner

As a maintainer I want the debug banner removed so the production code is clean
and test outputs are not polluted by developer-only logs.

**Acceptance Criteria:**
- [ ] Debug banner code removed from `AerodromeStandardExchangeCommon` target/facet
- [ ] Any dev-only `console.log` or event logging removed or gated behind debug flags
- [ ] Tests updated if they relied on debug banner text
- [ ] Build succeeds and tests pass

## Technical Details

- Search for debug/banner strings and remove rendering logic and test dependencies
- Prefer small, behavior-preserving changes — do not alter core logic
- If any logging remains necessary, gate it behind a `DEBUG` constant in test builds only

## Files to Create/Modify

**Modified Files:**
- `contracts/protocols/dexes/aerodrome/v1/*AerodromeStandardExchangeCommon*.sol` (remove debug banner)
- Tests referencing banner text under `test/` may need updates

## Inventory Check

- [ ] IDXEX-043 available and compiled

## Completion Criteria

- [ ] Debug banner removed and code compiles
- [ ] Tests updated and passing
- [ ] Build succeeds

---

**When complete, output:** `<promise>TASK_COMPLETE</promise>`

**If blocked, output:** `<promise>TASK_BLOCKED: [reason]</promise>`
