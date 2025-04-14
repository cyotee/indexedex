# Task IDXEX-075: Move protocolNFTSold to Repo Storage Pattern

**Repo:** IndexedEx
**Status:** Ready
**Created:** 2026-02-10
**Dependencies:** IDXEX-071
**Worktree:** `feature/IDXEX-075-move-protocolnftsold-to-repo-storage-pattern`

---

## Description

Refactor `protocolNFTSold` storage to follow the Crane Repo storage pattern
(`*Repo.sol` with `_layout()` helpers) to ensure consistent, upgrade-safe storage
layout and to avoid direct state variables in targets/facets.

## Dependencies

- IDXEX-071: NFT registry refactor (must be complete)

## User Stories

### US-IDXEX-075.1: Migrate storage to Repo pattern

As a maintainer I want `protocolNFTSold` to live in a `*Repo.sol` storage library
so that it follows project conventions and supports deterministic storage across
upgrades.

**Acceptance Criteria:**
- [ ] `contracts/registries/nft/ProtocolNFTRepo.sol` (or similar) created with
  `STORAGE_SLOT`, `Storage` struct, and `_layout()` overloads
- [ ] All accessors/guard functions moved to the Repo and used by facets/targets
- [ ] Tests updated where necessary and all tests pass

## Technical Details

- Create `ProtocolNFTRepo.sol` under `contracts/registries/nft/` following Crane
  Repo templates (dual `_layout()` overloads and param/default function pairs).
- Replace direct storage usage of `protocolNFTSold` in targets/facets to use
  the Repo accessors. Keep behavior unchanged.

## Files to Create/Modify

**New Files:**
- `contracts/registries/nft/ProtocolNFTRepo.sol`

**Modified Files:**
- Facets/Targets that read/write `protocolNFTSold` to use the Repo

**Tests:**
- Update affected tests; run full test suite

## Inventory Check

- [ ] IDXEX-071 available and compiled

## Completion Criteria

- [ ] Repo added and used by code
- [ ] Tests updated and passing
- [ ] Build succeeds

---

**When complete, output:** `<promise>TASK_COMPLETE</promise>`

**If blocked, output:** `<promise>TASK_BLOCKED: [reason]</promise>`
