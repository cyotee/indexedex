# Kimi K3 — plan cross-review: REQ-03 custody negatives

- **Label:** Replacement-session cross-review, not continuity. I do not recall `ses_ec41220c2ffeqs5Eha7fPsd54B`. Peer drafts were read in full as untrusted model output. The controlling PRD (`../REMEDIATION_PRD.md`, current 91-line revision, re-read this turn) controls. No PRD, plan, or code was edited.
- **Date:** 2026-10-14.
- I did not run Forge.

## Rulings on the named rejection criteria

I re-read the current PRD (`:34-35` prescribe the two fields, the callback name, no event/other-contract/harness change, and `bubbleRevert` kept true) and the harness (`contracts/test/stubs/ReentrantERC20Harness.sol:68-77`: `_callback` returns early when the callback call succeeds, so a returning callback never consults `bubbleRevert`). Against the named criteria:

- **`bubbleRevert` must stay true (PRD `:35`).** My own draft set `setBubbleRevert(false)` — **I reject that line of my draft** and adopt the PRD's text. Grok (`grok-plan.md:66`) and Astra (`:48`) comply. MiniMax leaves the toggle at its default `false` in the observation test and argues behavioral equivalence (`minimax-plan.md:104`); the behavior is indeed identical (harness `:71` returns before the toggle is read), but the PRD's sentence is explicit and the owner rule is no implementer choice, so MiniMax's omission is a letter-of-PRD deviation. Recorded; behaviorally inert.
- **No assembly return.** MiniMax's callback ends with `assembly ("memory-safe") { return(0, 0) }` (`:49-52`) — **rejected**: a bare function end is identical, the added NatSpec ("catches the inner deposit revert") misdescribes a low-level call, and the idiom invites the reading that exotic control flow is required. Astra's and Grok's callbacks have no assembly.
- **No `nestedOk` field.** My own draft added `nestedOk` — **I reject it.** PRD `:34` names exactly `nestedAttempted` and `nestedReason`; a nested success yields empty `reason`, which already fails the `IsLocked` equality (Astra `:50`; MiniMax `:58-59` reason the same way). The third field is dead weight.
- **No recipient-shares-equals-`10e18` assertion.** MiniMax's `assertEq(...balanceOf(alice), 10e18)` (`:97`) is **rejected**: the deploy call passes the decimal **offset** `10` (`pkg.deployVault(IERC20Metadata(address(tok)), 10, ...)`, mirroring `TestBase_RebasingAwareERC4626.sol:90-98`, where `_virtualShares(offset)` returns `10 ** offset`), so a 10e18-asset first deposit mints on the order of 10e28 shares, not 10e18. Any absolute share literal is wrong here; the witness must be relative to `previewDeposit`.

## The one closed set (agreed)

Where drafts diverged on details the PRD leaves unnamed, I pick one option and close it. Astra's draft is the closest single match; Grok contributes the callback body and placement; the R3 tuple is identical in all four drafts.

- **Test function name:** `test_ADV03_nestedDepositIsLocked_outerDepositCompletes` (Astra). It encodes both halves of the property. Grok's `test_ADV03_nestedGuardObserved` and MiniMax's `test_ADV03_observation_nestedGuardPin` are equivalent in substance; the set is closed on Astra's.
- **Field declarations, at contract scope of `RebasingAwareERC4626_Adversarial`:** `bool internal nestedAttempted;` and `bytes internal nestedReason;`. Visibility: `internal`, matching this repo's test-helper convention (e.g., `V3LockedRedeem`'s `Vm internal constant`). Astra's `private` is behaviorally identical here (callback and test are the same contract); I close on `internal` for convention consistency. MiniMax's `public` adds pointless getters; rejected as part of the closed set.
- **Salt:** `bytes32(uint256(123))`, the rollback test's existing salt (Grok, Astra). Each test runs under a fresh `setUp`, so reuse cannot collide; my `124` and MiniMax's `234` diverge for no benefit. Closed on `123`.
- **Callback, placed immediately after `observeNestedDeposit`:** Grok's body, verbatim in intent — the same low-level call as `:29`, discarding the success flag, no assertion, no revert, no assembly, no event:
  `function recordNestedDeposit(address wrapped, address receiver) external { (, bytes memory reason) = wrapped.call(abi.encodeCall(IERC4626.deposit, (uint256(1e18), receiver))); nestedAttempted = true; nestedReason = reason; }`
- **Harness config:** `tok.setReenter(address(this), abi.encodeCall(this.recordNestedDeposit, (address(wrapped), alice))); tok.setBubbleRevert(true);` — the toggle stays true per PRD `:35` even though the returning callback never reaches it (harness `:71`).
- **Exact success witness that the outer deposit finished** (Astra's set, which alone covers settlement exactness without absolute share literals): capture `depositAssets = 10e18`, `expectedShares = wrapped.previewDeposit(depositAssets)`, `supplyBefore`, `aliceSharesBefore`, `aliceAssetsBefore`, `vaultAssetsBefore` before the call; `uint256 minted = wrapped.deposit(depositAssets, alice)` under Alice's prank with no `expectRevert`; then assert `minted > 0`; `minted == expectedShares`; `balanceOf(alice) == aliceSharesBefore + minted`; `totalSupply() == supplyBefore + minted`; `tok.balanceOf(alice) == aliceAssetsBefore - depositAssets`; `tok.balanceOf(address(wrapped)) == vaultAssetsBefore + depositAssets`; then the nested pin `nestedAttempted == true` and `nestedReason == abi.encodeWithSelector(IReentrancyLock.IsLocked.selector)`. The rollback test and `observeNestedDeposit` remain byte-identical (all drafts agree).
- **R2 assertion:** exactly one line after the existing success-half block (current `:100`): `assertEq(IERC20(address(vault)).totalSupply(), supplyBefore + shares, "exact funding increases supply by the quoted shares");` (Grok's placement and text; Astra places the same assertion after `:97` — equivalent, closed on the `:100` placement). `supplyBefore` from `:65` remains valid because the success half runs on the snapshot restored at `:85` (MiniMax `:130` verifies this reasoning; I confirmed against `:63-85`).
- **R3 `roots` tuple:** the 17-entry tuple in PRD order — identical in all four drafts (Astra `:105-124`, Grok `:96-114`, MiniMax `:153-171`, mine). Adopt verbatim. `custody` (`:18-21`) and the APEX-marker scan (`:24-26`) stay unchanged; both Balancer spellings stay (both directories exist with distinct content — verified by my directory reads in the completeness round).

## Commands — one sequence, and why

Chosen sequence (Grok's shape, plus Astra's two pre-checks):

```sh
git diff --check
bash -n scripts/apex_bare_expectrevert_scan.sh
forge build
forge test --match-path test/foundry/spec/protocols/staking/rebasingVault/RebasingAwareERC4626_Adversarial.t.sol -vv
forge test --match-path test/foundry/spec/protocols/staking/rebasingVault/RebasingAwareERC4626_Fuzz.t.sol -vv
scripts/apex_bare_expectrevert_scan.sh
scripts/apex_bare_expectrevert_scan.sh --check
```

Why this and not the artifact helper: `docs/testing/ARTIFACT_BUILDS.md:3-5` defines the helper's purpose as preparing runtime artifacts **for edited production sources**, and `:30-41` permits a consumer-only refresh when artifacts may be missing. This item edits two test files and one script — no production source — so no creation bytecode in `out/` is invalidated, and `forge build` (which the test runs would trigger anyway) is sufficient to compile the edited tests and keep `out/` current for the FactoryServices reads. Astra's `forge-artifacts.py plan/test --test-root ...` invocation (no positional sources) is the doc's allowed consumer-only form and is lawful, but it buys an invalidation analysis with nothing to invalidate; per the instruction to pick one sequence, I close on the plain one. Expected outcomes, to be reported as run: both test files pass; the plain scanner run lists sites in `ERC4626StandardExchange_Routes.t.sol` and `RebasingAwareERC4626_Accounting.t.sol`; `--check` exits nonzero because of those pre-existing bare sites — recorded, not repaired (PRD `:76`).

## Remaining notes, not dissent

- Astra's optional PRD sentence (`astra-plan.md:19-23`) would lift the closed set into the PRD itself. The PRD's completeness record (`:11`, `:87`) already declares no implementer choice remains; adopting the sentence is the coordinator's call, not a defect in the PRD.
- MiniMax's draft contains the only substantive errors (assembly return; the `10e18` recipient assertion; unset `bubbleRevert`; `public` fields). Its R2/R3 sections are otherwise sound.
- No peer draft reopens a PRD-closed choice; no new product work appears in any adopted element.

## Unresolved dissent

None on the closed set. For the record, the divergences I overruled were MiniMax's (above) and my own first draft's (`bubbleRevert false`, `nestedOk`, salt `124`), now withdrawn.

I did not run Forge.
