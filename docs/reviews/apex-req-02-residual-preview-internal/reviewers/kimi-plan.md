# Kimi K3 plan draft — REQ-02: residual preview stays internal and direct

- **Label:** Replacement-session draft. This is not continuity of any earlier Kimi session, including `ses_ec41220c2ffeqs5Eha7fPsd54B`. No prior plan or peer artifact was read for this draft.
- **Date:** 2026-10-14
- **Status:** DRAFT. Writing this plan does not authorize code edits. A later session must be explicitly asked to implement it.
- **Controlling PRD:** `docs/reviews/apex-req-02-residual-preview-internal/REMEDIATION_PRD.md` (2026-10-14, owner request: change `previewResidualBuffer` from `external` to `internal`). Where this plan conflicts with that PRD, the PRD controls.
- **Execution evidence:** I did not run Forge. All citations below are lines I read this round; PRD line numbers may have drifted and were re-derived.

## Objective

Make `previewResidualBuffer` an `internal` direct quote in the ClaimLib, keep the four sweep zero-stops intact, and add the two production-path tests (zero quote retains; reverting quote rolls back) on the production hook diamond. No catch is added. No second caller check is added. `bufferQuotedResidual` stays `external`.

## Current state, as re-read

**The function** — `contracts/hooks/uniswap/v4/standardExchange/constantProduct/single/UniswapV4SingleStandardExchangeBufferConstantProductHookClaimLib.sol:384-389`: `external view`, body is a storage read plus a direct `IStandardExchangeIn(l.standardExchange).previewExchangeIn(IERC20(l.pairToken), amount, IERC20(l.standardExchange))`. No catch. `bufferQuotedResidual` is at `:393`, `external`. The zero-quote comment is at `:382-383`.

**Repo-wide caller inventory (grep, `contracts/` only):** the name `previewResidualBuffer` appears in exactly five files — the ClaimLib definition and the four sweep sites. No interface declares it; no test or script calls it. All four call sites are internal/library call sites (`ClaimLib.previewResidualBuffer(excess)`), which compile unchanged against an `internal` library function (inlined). PRD step 3's stop-and-report contingency is therefore expected to be unused; it stays armed.

**The four sweeps (all have the `if (preview == 0) return` stop):**

| # | Sweep copy | Lines read | Production reachability |
| --- | --- | --- | --- |
| 1 | `UniswapV4SingleStandardExchangeBufferConstantProductHookDepositCommon.sol` `_refundPairDust` | `:367-379` (stop `:376`) | **Reached.** Called by `_deposit` (`:491`), `_depositWithSeShares` (`:582`), `_depositSingle` (`:712`). Public entries on the deployed diamond: `deposit`, `depositWithPermit2Signature`, `depositWithPermit2Allowance`, `joinProportional`, `joinUnbalanced`, `depositWithSeShares` (`...HookDepositTarget.sol:21,42,65,77,96,128`) and `depositSingle` + permit2 variants (`...HookDepositSingleTarget.sol:64,76,89`). DepositFacet → DepositTarget → DepositCommon; DepositSingleFacet → DepositSingleTarget → DepositCommon (facet files under `facets/`). |
| 2 | `UniswapV4SingleStandardExchangeBufferConstantProductHookWithdrawalLib.sol` `refundPairDust` | `:131-142` (stop `:139`) | **Reached.** Wrapped by `...HookWithdrawTarget.sol:_refundPairDust` (`:338-340`), called from `_withdraw` (`:536`) and `_withdrawSeShares` (`:575`). Public entries: `withdraw` (`:477`), `withdrawSeShares` (`:497`). The WithdrawalLib-internal `refundPairDust()` call at `:66` sits inside a WithdrawalLib withdraw-single flow; I did not confirm which production function reaches that linkage — `withdraw` and `withdrawSeShares` are the entries verified end-to-end. |
| 3 | `UniswapV4SingleStandardExchangeBufferConstantProductHookTarget.sol` `_refundPairDust` (monolith) | `:388-400` (stop `:397`) | **Not reached by the current deployment shape.** In-file callers exist (`:846`, `:971`, `:1139`, `:1215`), but the deployed package (`...Hook_FactoryService.sol:25-63`, TestBase `:115-125`) installs Se/Deposit/DepositSingle/DepositPreview/Withdraw facets, and no contract in `contracts/` inherits the monolith Target (inheritance/import grep found only doc/evidence references). The PRD says "Target has callers" — true in-file, but no deployed facet routes to them. Treat like the SeTarget copy: cite it, do not add an entry to reach it. |
| 4 | `UniswapV4SingleStandardExchangeBufferConstantProductHookSeTarget.sol` `_refundPairDust` | `:477-489` (stop `:486`) | **Not reached.** No caller in the file (grep). SeFacet → SeTarget is deployed, but no function in SeTarget calls this copy. Cite per PRD; do not add an entry. |

**Dust floor:** `MAX_DUST_WEI = 10` at `...HookRepo.sol:19`. The sweeps quote `excess = balance - MAX_DUST_WEI` only when the balance is above the floor (`DepositCommon:373-374`, `WithdrawalLib:136-137`, `Target:394-395`, `SeTarget:483-484`).

**TestBase:** `contracts/hooks/uniswap/v4/standardExchange/constantProduct/single/TestBase_UniswapV4SingleStandardExchangeBufferConstantProductHook.sol`. It deploys a real ERC-4626 wrapper SE over the `SimpleYieldERC4626` harness (`:86-89`), a hermetic PoolManager via CREATE3 (`:92-96`), and the hook diamond through the package + registry path (`:99-137`) with `_bindProductPoolKey()` (`:139`). Useful helpers: `_depositBoth` (`:279`), `_seedLiveLiquidity` (`:292`), `_mintSeSharesToUser` (`:153`), `_feeTo` (`:297`), `_enableProtocolFee` (`:286`). The existing deploy test to sit beside is `test/foundry/spec/hooks/uniswap/v4/standardExchange/constantProduct/single/UniswapV4SingleStandardExchangeBufferConstantProductHook_Deploy.t.sol`.

**Bound SE quote path (for both test cases):** the sweep's quote resolves to `ERC4626StandardExchangeCommon._previewExchangeIn` (`contracts/vaults/standard/erc4626/ERC4626StandardExchangeCommon.sol:35-70`), underlying→SE-shares branch at `:51-53`: `vault.convertToShares(amountIn)` then `_convertVaultDeltaToShares(receiptEquiv, _receiptBacking())` (`:131-139`). `_receiptBacking()` (`:102-104`) reads the harness through `ReceiptBackedERC4626AccountingLib.backingReceiptUnits` (`ReceiptBackedERC4626AccountingLib.sol:18-30`), whose external reads are `receipt.balanceOf(holder)` (`:23`), `receipt.asset()` (`:24`), and `receipt.convertToShares(...)` (`:51`). Verified: this preview path has **no** disable or pause check (no `_requireNotDisabled` anywhere in `contracts/vaults/standard/erc4626/`), and `_requireNonZero` (`:38`) is unreachable from a sweep because `excess ≥ 1` whenever the sweep quotes. `SimpleYieldERC4626` (`contracts/test/stubs/SimpleYieldERC4626.sol`) has no revert mode in its quote functions (`:102-132`); `simulateYield` (`:187-190`) raises `totalAssetsStored` without minting shares — the production-grade lever for the Case 1 zero quote.

## Ordered steps

1. **Visibility change.** In `UniswapV4SingleStandardExchangeBufferConstantProductHookClaimLib.sol:384`, change `function previewResidualBuffer(uint256 amount) external view` to `internal view`. Do not touch the body (`:385-388`), the comment (`:382-383`), or `bufferQuotedResidual` (`:393`, stays `external`). Do not add a catch or a zero check inside the preview.
2. **Compile-caller check.** Build. My grep this round found no caller outside the four sweep sites and no interface declaration, so the change should compile as an inline. If any caller fails to compile against the internal function, stop and report that caller per PRD step 3; do not leave the function `external` to hide the failure, and do not add a public wrapper (the hook must not grow a selector for it).
3. **Sweep integrity check (no edits expected).** Confirm the zero stop is unchanged at `DepositCommon:376`, `WithdrawalLib:139`, `Target:397`, `SeTarget:486`, and that no sweep was otherwise edited. This is a read-back, not a rewrite.
4. **Tests.** Add one new file beside the deploy test, e.g. `test/foundry/spec/hooks/uniswap/v4/standardExchange/constantProduct/single/UniswapV4SingleStandardExchangeBufferConstantProductHook_ResidualPreview.t.sol`, inheriting `TestBase_UniswapV4SingleStandardExchangeBufferConstantProductHook`. No `new` on SUT components; use the base's registry/package deploy path unchanged. Four test functions, detailed below. Cite in the file's header comment that the monolith-Target and SeTarget sweep copies have no production caller (this round's evidence: no inheritance of the monolith; no call site in SeTarget) and are therefore not exercised, per the PRD's reachability rule.
5. **Artifact refresh, then run.** The visibility change is a production edit: run `python3 scripts/forge-artifacts.py` before `forge test` (FactoryServices read creation bytecode from `out/`). Then run the new file and the sibling suites for this hook family. Report the commands actually run; a present assertion is not a pass until the run is reported.
6. **Report.** State which sweep copies were exercised (DepositCommon via `deposit`; WithdrawalLib via `withdraw`), which were cited as unreached (monolith Target, SeTarget), and whether Case 2 used the harness-fault construction (below) or was reported unreached.

## Test construction on the production TestBase

Shared fixture for both cases (per test, after `setUp`):

- Seed the SE so `totalSupply > 0`: `_mintSeSharesToUser(100 ether)` (TestBase `:153-168`) or an equivalent direct `exchangeIn` on `se`.
- Case 1 only — make the excess quote zero: mint pair to the test contract and call `pairProtocolVault.simulateYield(...)` with a large amount (the DETF precedent raised backing by `1e30`; `UniswapV4DetfLeftoverPreview.t.sol:41-42`) so `convertToShares(excess)` floors to 0 for a wei-sized excess, and `sharesFromReceiptUnits(0, ...)` returns 0 (`ReceiptBackedERC4626AccountingLib.sol:59-60` return the delta; the zero comes from `convertToShares` flooring at `SimpleYieldERC4626.sol:105`).
- Put the hook above the dust floor: `pairToken.mint(hook, DUST + excess)` with `excess` small (a few wei). This is a donation into custody, not a mock; the sweep reads raw `balanceOf` (`DepositCommon:372`, `WithdrawalLib:135`).
- **Witness precondition (PRD Case 1 step 3):** call `IStandardExchangeIn(se).previewExchangeIn(IERC20(address(pairToken)), excess, IERC20(se))` from the test — the same view the sweep uses after inlining. The test is Case 1 only if this returns 0. If no reachable excess quotes 0 on this vault, stop and report that the zero case was not reached; do not replace the vault to force a zero.

### Case 1 — quote returns zero (two tests, one per reachable sweep)

`test_REQ02_zeroQuote_depositSweepRetainsExcess`:

1. Fixture as above; record hook pair balance, `excess`, hook SE balance, `user` pair balance, `_feeTo()` pair balance.
2. `vm.prank(user)`; call `single.deposit(a0, a1, user, 0, block.timestamp + 1 hours)` with both legs fully consumable at the current reserve ratio (seed first via `_seedLiveLiquidity()` so a balanced deposit creates no new pair remainder). The call must succeed; its LP mint is the operation's own payout.
3. Assert: `pairToken.balanceOf(hook) == DUST + excess` (the pre-existing dust is intact; the balanced deposit added no remainder); `IERC20(se).balanceOf(hook)` increased only by the operation's own intake (assert the delta is unchanged from an identical deposit executed without the dust donation, or equivalently that no deposit of `excess` occurred — the dust is still pair, not shares); caller pair balance changed only by the pull; `feeTo` pair balance unchanged.
4. The test fails if the sweep deposits the excess, pays it out, or the call reverts because the quote was zero.

`test_REQ02_zeroQuote_withdrawSweepRetainsExcess`: same fixture; seed LP to `user` (`_seedLiveLiquidity`), donate the dust, then `vm.prank(user)` `single.withdraw(lpSlice, user, 0, 0, block.timestamp + 1 hours)`. Withdrawal's own payout is raw + unwrapped pair (`WithdrawTarget:523-530`) and must still meet its own minimums; assert it is not conflated with the dust by checking `pairToken.balanceOf(hook) == DUST + excess` after the call and that the caller's pair delta equals the withdrawal's own quoted pair leg, not the dust. Hook SE balance must not have increased by a deposit of the excess.

### Case 2 — quote reverts (two tests, one per reachable sweep)

No production state of the bound ERC-4626 SE reverts this preview (verified above: no disable/pause check on the preview path, `_requireNonZero` unreachable, the harness quote math cannot revert). The planned construction therefore faults a **non-SUT harness read**, mirroring the accepted sibling precedent (`UniswapV4DetfLeftoverPreview.t.sol:91-97`, which faulted a non-SUT token's `balanceOf` while keeping the SE and DETF proxies real):

`test_REQ02_revertingQuote_depositSweepRollsBack`:

1. Same fixture as Case 1 but without the yield donation (a positive quote is fine; it is never reached).
2. `bytes memory fault = abi.encodeWithSignature("ResidualPreviewDependencyFailure()")`; `vm.mockCallRevert(address(pairProtocolVault), abi.encodeWithSelector(IERC20.balanceOf.selector, se), fault)`. This reverts inside `_receiptBacking()` during the sweep's quote, on the production SE, with the production hook.
3. Record hook pair balance, hook SE balance, caller balances. Call the same `deposit` entry. Expect the call to revert with `fault` (the quote's revert, not a later unrelated check — the fault selector is distinct from any vault error). Assert recorded balances unchanged. `vm.clearMockedCalls()`.

`test_REQ02_revertingQuote_withdrawSweepRollsBack`: same, through `withdraw`.

If the coordinator rules that faulting the protocol-vault harness read violates "Do not mock the vault," then Case 2 is **not reachable** on this bound vault: stop, report that the revert case was not reached, and do not fake it (PRD Case 2 step 5). Do not add a catch to make Case 1 pass; Case 1 does not depend on the mock.

### What neither test may do (from the PRD, restated as checklist)

- No new public wrapper around `previewResidualBuffer`; no new selector.
- No bare `expectRevert()` — Case 2 names the fault bytes.
- Zero is not the revert case; a revert is not the zero case.
- No mock of the hook or the SE; the faulted harness read does not replace either.

## What must not change

- `bufferQuotedResidual` stays `external` (`ClaimLib:393`).
- All four `if (preview == 0) return` stops stay (`DepositCommon:376`, `WithdrawalLib:139`, `Target:397`, `SeTarget:486`); no fifth zero check is added anywhere.
- No `catch` in or around the preview; a reverting quote must propagate.
- `bufferPair` in `WithdrawalLib:70-80` is untouched (it has its own zero stop and is not this function).
- Reserve sync stays before the sweep (`DepositCommon:489-491`, `WithdrawTarget:534-536` / `:573-575`); do not move it after.
- The `to` argument stays unused; no dust is paid to `msg.sender` or `feeTo`.
- This item does not reopen REQ-C04: the hook-join preview rollback rule is a different path (`UniswapV4DetfCommon.sol`), and a successful SE preview of zero here must **not** revert the parent.
- No deployment, migration, or live-instance change.

## Blocking question

One, scoped to Case 2 only: the bound ERC-4626 SE exposes no production state (disable, pause, or otherwise) that reverts `previewExchangeIn` for a valid nonzero excess, and the PRD prefers such a state while forbidding mocks of the hook and the SE. I plan to fault the non-SUT `SimpleYieldERC4626` harness `balanceOf(se)` read so the production SE's own preview reverts — the same construction the council accepted for the sibling REQ-01 test (`UniswapV4DetfLeftoverPreview.t.sol:91-97`). If that construction is ruled a vault mock, Case 2 will be reported as not reached rather than faked. This does not block the visibility change, Case 1, or the sweep-integrity work. No other blocking questions.

## Done when

- `previewResidualBuffer` is `internal view` in `ClaimLib`, body unchanged, no catch; `bufferQuotedResidual` still `external`.
- The build compiles with no caller left behind (or the offending caller was reported and the change stopped, per PRD step 3).
- All four sweep zero-stops verified unchanged by read-back.
- Four new tests exist on the production TestBase: zero-quote deposit sweep, zero-quote withdraw sweep, reverting-quote deposit sweep, reverting-quote withdraw sweep — or the report states precisely which case was not reached and why.
- The monolith-Target and SeTarget sweep copies are cited as unreached in the test file header, with the no-inheritance/no-caller evidence.
- Artifacts were refreshed (`python3 scripts/forge-artifacts.py`) before `forge test`; the commands actually run are reported; no pass is claimed without the run.
- No selector for `previewResidualBuffer` appears on the hook diamond (loupe check may be included in the deploy-adjacent test).

I did not run Forge.
