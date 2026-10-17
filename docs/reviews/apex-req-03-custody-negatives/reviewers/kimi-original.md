# Kimi K3 — original: REQ-03 custody negatives, remaining gaps

- **Label:** Replacement-session original, not continuity. I do not recall `ses_ec41220c2ffeqs5Eha7fPsd54B`. No `reviewers/` directory for this round was read; no peer text was used. I did not write or read `docs/reviews/apex-req-03-custody-negatives/REMEDIATION_PRD.md`.
- **Date:** 2026-10-14.
- **Question:** Which acceptance bullets of Stage-1 REQ-03 are still open in the current tree, and what exact PRD requirements would close only those gaps?
- **Controlling text:** `docs/reviews/apex-2026-09-17-second-audit-readiness/REMEDIATION_PRD.md` REQ-03, `:223-235` (re-read in full this round).
- **Execution evidence:** I did not run Forge. A present assertion is not a passing run.

## Bullet verdicts

### Bullet 1 — ownership test: contract caller, precise share-accounting error, other holder unchanged — **already satisfied**

`test/foundry/spec/protocols/staking/rebasingVault/RebasingAwareERC4626_Adversarial.t.sol:50-61` (`test_ADV_cannotBurnOtherHolderViaInternalSy`) now drives the internal-balance redeem through an `AtomicPretransferCaller` contract caller (`:55-56`), so the bytecode gate at production `RebasingAwareStandardYieldTarget.sol:57-59` passes and the named share-accounting condition is actually reached. It expects the precise error `TransferDeltaInsufficient(shares, 0)` (`:57`) and asserts the other holder's shares and the reserve are unchanged (`:59-60`). The code-less-caller rejection is separately pinned by `test_ADV_publicSharesArePublic` (`:76-89`). The production guard is intact and untouched, as the non-goal requires.

### Bullet 2 — reentrancy test: expects the nested-guard error and asserts no partial credit — **partial**

Current shape: `observeNestedDeposit` (`RebasingAwareERC4626_Adversarial.t.sol:28-33`) asserts the nested `deposit` is rejected and that its revert reason is exactly `IReentrancyLock.IsLocked` (`:30-31`), then deliberately re-bubbles `IsLocked` (`:32`). `test_ADV03_reentrancyDuringDepositReverts` (`:128-147`) expects `SafeTransferLib.TransferFromFailed` on the outer deposit (`:140`) and asserts no partial credit — supply, caller shares, vault assets, and reserve all unchanged (`:143-146`).

The residual gap: the file's own comment (`:26-27`) states that a wrong nested error fails the callback assertion and "the vault then reports the pull as TransferFromFailed" — the same selector the outer test expects. So the outer `vm.expectRevert(TransferFromFailed)` is satisfied whether the nested frame produced `IsLocked`, a different error, or a failed assertion: the `:31` pin is not load-bearing at the test-oracle level. Fact: the comment, the wrap, and the matching outer expectation are as cited. Inference (unexecuted): this is the standard Foundry pattern in which an assertion failure inside a callback is swallowed by an outer `expectRevert` whose reason matches after wrapping; I did not run Forge to confirm the runner semantics. Under R2.4's stated intent ("a test named for a ... reentrancy property must reach that property", PRD `:227`), an unrelated nested failure can still preserve a green result, so this bullet is not fully closed. Proposed requirement P-1 below.

### Bullet 3 — minimality fuzz: exact short-funding error, unchanged state on rejection, exact on success — **already satisfied**

`test/foundry/spec/protocols/staking/rebasingVault/RebasingAwareERC4626_Fuzz.t.sol:57-101` (`testFuzz_FUZZ02_exactOutMinimals`): rejection half pins the family's exact error `MaxAmountExceeded(need - 1, need)` (`:70`) and asserts shares, supply, caller assets, vault assets, and reserve unchanged (`:80-84`); success half asserts `paid == need` and exact mint/debit/credit/booking (`:96-100`).

### Bullet 4 — scanner selects the full D16 regression inventory used for R2.4 — **still open**

Current selection rule (`scripts/apex_bare_expectrevert_scan.sh:14-26`): two fixed roots (`test/foundry/spec/hooks/uniswap/v4/standardExchange`, `test/foundry/spec/vaults/standard/exchange/protocols/uniswap`), the two named custody files (`:18-21` — the "including custody files that do not contain the APEX marker" clause is satisfied), plus any `test/foundry/spec` file containing an APEX marker.

Demonstrated escapes from that selection, read this round:

- `test/foundry/spec/vaults/standard/erc4626/ERC4626StandardExchange_Routes.t.sol:332,335,383,409,559` — five bare `vm.expectRevert()` calls; the file contains no APEX marker (grep count 0) and its directory is under neither fixed root. The ERC-4626 SE is a D16 family.
- `test/foundry/spec/protocols/staking/rebasingVault/RebasingAwareERC4626_Accounting.t.sol:131,143` — bare `vm.expectRevert()` in the same custody directory as the two named files, with no APEX marker and no explicit inclusion; nine further rebasingVault spec files also contain bare `expectRevert()` (grep, files-with-matches). These sibling custody files are exactly the class the bullet's "including custody files" clause gestures at, yet only two are named.

So the custody clause is satisfied but the full-inventory clause is not, on current evidence. Boundary of this claim: the definitive "full D16 regression inventory used for R2.4" cannot be derived from the cited PRD and the script alone. The documents that would define it are the locked plan's D16 family scope (`docs/audits/apex-2026-09-17-remediation-and-regression-tests.plan.md`, e.g. the D16 decision rows at `:99`, `:105`, `:110`, `:224`) together with the R2.4 evidence bundle under `docs/audits/apex-2026-09-17-evidence/`. I did not re-derive that inventory and do not invent a file list here; the two files above are cited as demonstrated escapes, not as the inventory. Proposed requirement P-2 below.

## Proposed requirements for the still-open gaps only

### P-1 — Make the nested-guard error pin load-bearing in `test_ADV03_reentrancyDuringDepositReverts`

- **Severity:** Medium (REQ-03's severity; impact class unchanged — false-positive coverage of a named reentrancy property).
- **File and line:** `test/foundry/spec/protocols/staking/rebasingVault/RebasingAwareERC4626_Adversarial.t.sol:26-33` (`observeNestedDeposit`) and `:128-147` (the test).
- **Intended behavior (REQ-03, `:227`, `:232`):** "A test named for an ownership or reentrancy property must reach that property. ... The reentrancy test expects the nested-guard error and asserts no partial credit." R2.4: an unrelated revert must not preserve a green result.
- **Broken requirement or invariant:** The outer expectation `vm.expectRevert(SafeTransferLib.TransferFromFailed.selector)` (`:140`) matches the vault's wrapped pull failure regardless of why the nested frame reverted (comment `:26-27` describes the wrap). A nested rejection with a different error, or a nested success that later fails for an unrelated reason, yields the same outer selector and the same unchanged post-state, so the `:31` `IsLocked` equality cannot currently fail the test.
- **Acceptance criteria:**
  - The nested call's `(ok, reason)` is recorded where the wrap cannot erase it (for example, stored on the test contract before the deliberate re-bubble at `:32`) and asserted after the outer call: `ok == false` and `reason == abi.encodeWithSelector(IReentrancyLock.IsLocked.selector)`.
  - The test demonstrably fails if the nested error is not `IsLocked`, and fails if the nested deposit succeeds. (This is a test-design property to be shown by the implementer's run; I did not run Forge.)
  - The existing no-partial-credit assertions (`:143-146`) are retained unchanged.
  - The production guard (`RebasingAwareStandardYieldTarget.sol:57-59`) and the vault's pull behavior are not edited; this is a test-oracle repair only.
- **Non-goals:** Do not weaken the bytecode/EOA guard. Do not broaden any `expectRevert`. Do not change production code to make the test observable. Do not restate this as a new finding about the production reentrancy lock — no production defect is claimed.

### P-2 — Bind the scanner to the defined D16 R2.4 inventory

- **Severity:** Medium (REQ-03's severity; impact class unchanged — unpinned negatives outside the gate).
- **File and line:** `scripts/apex_bare_expectrevert_scan.sh:14-26`; demonstrated escapes at `test/foundry/spec/vaults/standard/erc4626/ERC4626StandardExchange_Routes.t.sol:332,335,383,409,559` and `test/foundry/spec/protocols/staking/rebasingVault/RebasingAwareERC4626_Accounting.t.sol:131,143`.
- **Intended behavior (REQ-03, `:234`):** "The scanner selects the full D16 regression inventory used for R2.4, including custody files that do not contain the APEX marker."
- **Broken requirement or invariant:** The selection rule (two fixed roots + two named custody files + APEX-marker filter) demonstrably does not cover D16-family regression files that carry bare `vm.expectRevert()` and no APEX marker — the two cited files are concrete instances, not an invented list.
- **Acceptance criteria:**
  - The D16 R2.4 inventory is first defined from the locked plan's D16 scope (`docs/audits/apex-2026-09-17-remediation-and-regression-tests.plan.md`) and the R2.4 evidence bundle (`docs/audits/apex-2026-09-17-evidence/`), and recorded where the scanner can consume it (an explicit inventory file or an equivalent expansion of the fixed roots).
  - With that inventory, the scanner selects the two cited escaping files (or their documented successors) and every other inventory member, with or without an APEX marker.
  - The scanner still rejects bare `expectRevert()` under `--check`; its comment-stripping and line-number behavior (`:27-38`) are unchanged.
  - Files pinned to exact errors remain green; this requirement expands selection, not assertion style.
- **Non-goals:** Do not invent the inventory from search results. Do not rewrite the pinned tests in the newly selected files under this item; selection only. Do not change the two named custody files' inclusion. Do not weaken the production EOA guard anywhere. Do not run the scanner as part of this review item's acceptance without a separately authorized execution session.

## What is not open

- The production bytecode guard stands unchanged (`RebasingAwareStandardYieldTarget.sol:57-59`); no requirement should touch it.
- `test_ADV02_insufficientSharePretransferReverts` (`:113-126`) remains a correctly pinned contract-caller control, as the PRD notes.
- No broader `expectRevert()` is proposed anywhere above.

## Files examined with no defect found (for the scoped bullets)

- `RebasingAwareERC4626_Adversarial.t.sol` (full read, 225 lines) — bullets 1 and 2 assessed; the pinned ownership test and the ADV02 control need no change.
- `RebasingAwareERC4626_Fuzz.t.sol:50-124` — bullet 3 satisfied.
- `scripts/apex_bare_expectrevert_scan.sh` (full read, 47 lines).
- `contracts/protocols/staking/rebasingVault/RebasingAwareStandardYieldTarget.sol:53-67` — guard intact.
- `docs/audits/apex-2026-09-17-remediation-and-regression-tests.plan.md` (D16 rows only, via grep) — used to identify where the inventory is defined, not to derive it.

## Evidence gaps

- I did not run Forge; the P-1 swallowing analysis is inference from the code shape and the file's own comment, not an executed result. A permitted run would settle it directly (mutate the nested error and observe the test).
- The full D16 R2.4 inventory was not re-derived; P-2 assigns that definition step to the named documents rather than guessing the list.
- The remaining rebasingVault sibling files with bare `expectRevert()` were enumerated by grep but not body-read; they are evidence of the selection gap, not individually adjudicated tests.

I did not run Forge.
