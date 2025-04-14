# Task IDXEX-011: Review Storage Layout Verification

**Repo:** IndexedEx
**Status:** Ready
**Created:** 2026-01-12
**Type:** Code Review
**Dependencies:** None
**Worktree:** N/A (review task)

---

## Description

Review storage slot safety across upgrades and Diamond cuts. Ensure no storage slot collisions exist between Repos in the Diamond architecture.

## Review Focus

Ensure storage slot safety across upgrades and Diamond cuts.

## Primary Risks

- Storage slot collisions between Repos (catastrophic in Diamond pattern)
- Storage layout changes breaking upgrades
- Namespace string duplicates

## Storage Verification Commands

### Pre-Change Verification
```bash
# Capture current storage layout
forge inspect <RepoContract> storage-layout --pretty > storage_before.json
```

### Post-Change Verification
```bash
# Capture new storage layout
forge inspect <RepoContract> storage-layout --pretty > storage_after.json

# Diff the layouts
diff storage_before.json storage_after.json
```

## Verification Rules

| Rule | Description | Severity if Violated |
|------|-------------|---------------------|
| **No slot changes** | Existing fields must keep their slot numbers | Blocker |
| **No type changes** | Existing fields must keep their types | Blocker |
| **Append-only** | New fields must be added after existing fields | Blocker |
| **No reordering** | Field order must be preserved | Blocker |
| **Namespace isolation** | Different Repos must use different namespace hashes | Blocker |

## Review Checklist

### Storage Slot Collision Checks
- [ ] Search for `STORAGE_SLOT` definitions across all Repos
- [ ] Verify no duplicate namespace strings exist
- [ ] Document all namespace strings used

### Per-Repo Verification

For each `*Repo.sol` in the codebase:
- [ ] Has unique `STORAGE_SLOT` constant
- [ ] Uses unique namespace string
- [ ] No collision with any other Repo

### Cross-Repo Collision Check
- [ ] IndexedEx Repos don't collide with each other
- [ ] IndexedEx Repos don't collide with Crane Repos
- [ ] IndexedEx Repos don't collide with any in-repo submodule Repos

### New Repo Documentation
For any new Repo introduced:
- [ ] Reviewer note records the namespace string used
- [ ] Namespace string follows project convention

## Files to Review

**All Repo Files:**
- `contracts/**/*Repo.sol`
- `lib/daosys/lib/crane/contracts/**/*Repo.sol` (Crane repos used by IndexedEx)

## Completion Criteria

- [ ] All checklist items verified
- [ ] Complete list of STORAGE_SLOT values documented
- [ ] No collisions found (or collisions fixed)
- [ ] Findings documented in `docs/reviews/YYYY-MM-DD_IDXEX-011_storage-layout.md`
- [ ] No Blocker severity issues remain unfixed

---

**When complete, output:** `<promise>TASK_COMPLETE</promise>`

**If blocked, output:** `<promise>TASK_BLOCKED: [reason]</promise>`
