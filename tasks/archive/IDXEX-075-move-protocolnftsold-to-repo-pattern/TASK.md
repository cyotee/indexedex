# Task IDXEX-075: Move protocolNFTSold to Repo Storage Pattern

**Repo:** IndexedEx
**Status:** Ready
**Created:** 2026-02-07
**Dependencies:** IDXEX-071 (complete)
**Worktree:** `feature/move-protocolnftsold-to-repo-pattern`
**Origin:** Code review suggestion from IDXEX-071

---

## Description

`protocolNFTSold` is currently a direct state variable on `ProtocolNFTVaultTarget` (slot 0 in the proxy). While harmless for pre-deployment code, this is inconsistent with the Repo storage pattern used everywhere else in the Diamond pattern architecture. Moving it to `ProtocolNFTVaultRepo` would prevent future storage collision risks if another facet accidentally declares a state variable.

(Created from code review of IDXEX-071, Suggestion 1)

## Dependencies

- IDXEX-071: Refactor ProtocolNFTVault Fee Oracle Storage to StandardVaultRepo (complete)

## User Stories

### US-IDXEX-075.1: Move protocolNFTSold to ProtocolNFTVaultRepo

As a developer, I want `protocolNFTSold` to use the namespaced Repo storage pattern so that it is consistent with all other state variables and immune to storage slot collisions.

**Acceptance Criteria:**
- [ ] `bool public protocolNFTSold` state variable removed from `ProtocolNFTVaultTarget`
- [ ] `protocolNFTSold` stored in `ProtocolNFTVaultRepo` using namespaced keccak storage
- [ ] Getter function maintained (public visibility preserved or explicit getter added)
- [ ] `markProtocolNFTSold()` writes via Repo pattern
- [ ] All reads of `protocolNFTSold` go through Repo pattern
- [ ] No raw slot 0 state variables remain in ProtocolNFTVault facets
- [ ] All existing Protocol NFT Vault tests pass
- [ ] Build succeeds

## Files to Create/Modify

**Modified Files:**
- `contracts/vaults/protocol/ProtocolNFTVaultTarget.sol` — Remove state variable, use Repo
- `contracts/vaults/protocol/ProtocolNFTVaultRepo.sol` — Add `protocolNFTSold` to storage struct

## Inventory Check

Before starting, verify:
- [ ] IDXEX-071 is complete
- [ ] `protocolNFTSold` is the only remaining direct state variable on ProtocolNFTVaultTarget
- [ ] Understand all read/write sites for `protocolNFTSold`

## Completion Criteria

- [ ] All acceptance criteria met
- [ ] All tests pass (no regressions)
- [ ] Build succeeds

---

**When complete, output:** `<promise>TASK_COMPLETE</promise>`

**If blocked, output:** `<promise>TASK_BLOCKED: [reason]</promise>`
