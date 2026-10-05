# Cross-review — Grok

Reviewer: Grok (xai/grok-4.7). This file is the cross-review only. Original findings remain in `grok-original.md` and are not rewritten. Peer text was treated as untrusted evidence, then checked against current source where cited. No code was edited. No tests were run. Completion JSON is still not proof.

## Method

Read in full: `astra-original.md`, `minimax-original.md`, `kimi-original.md`. Re-read current source for Astra-01 through Astra-06, Kimi F1–F3, and the matrix-count claim behind MiniMax M3-04. Grepped `docs/audits/apex-2026-09-17-evidence.md` for an owner exception covering the Uni V4 DETF catches. Did not read other cross-reviews or `docs/reviews/apex-2026-09-17-remediation-council/`.

## Agreements

- **Astra, Kimi, and Grok:** the 108-criterion completion claim is not substantiated by inspection. A green-count narrative is not closure. Live instances and D12 are accepted residuals, not missed source rewrites. D57 is not a missed Slipstream rewrite.
- **Kimi F1 confirms Grok finding 1.** Same file, same catch class. See below.
- **Kimi F2 confirms Grok finding 2.** Same function. See below.
- **Astra-01, Astra-02, Astra-03, Astra-05, Astra-06:** agreed after re-read. These were unverified in the Grok first pass. They are now confirmed defects or evidence defects.
- **MiniMax M3-01 and M3-02:** agreed as documented residuals, not as new broken requirements. They do not support a ready verdict.
- **MiniMax M3-04:** agreed that the matrix counts in the follow-up record and in `r12-gating.json` do not match. Neither count was re-executed.
- **MiniMax M3-09:** agreed that the acceptance ledger cannot be treated as a reconciled closure. Grok finding 3 is the stronger statement of that problem.

## Specific objections

- **MiniMax ready-with-documented-residuals:** disagree. MiniMax's readiness reasons are the completion manifest, hermetic counts, and matrix counts. The assignment forbids treating those as proof. Confirmed current-source and current-test defects (Grok 1–2, Astra-01 through Astra-03, Astra-05, Astra-06) are not the accepted D12 / live-instance residuals. MiniMax also says the JSON is not a security claim, then uses it as a reason the tree is ready. That is inconsistent.
- **MiniMax M3-03:** disagree as a current "still PARTIAL" defect. The cited PARTIAL list is an earlier evidence snapshot. The follow-up claims a later fork pass. That later pass was not re-run here, so fork closure stays **unverified**, not adopted as an open PARTIAL.
- **MiniMax M3-06:** do not adopt. It is explicitly speculation. The burn sites were not re-read in this cross-review.
- **MiniMax M3-07:** disagree that the locked D41/D48/D49 probes are themselves a broken requirement. They are recorded exceptions. The additional soft path is Astra-05, which MiniMax did not separate from those exceptions.
- **MiniMax M3-08 and M3-10:** not adopted as confirmed defects. M3-08 was not re-read in matrix tolerance bodies beyond Astra-02's weaker share assertion. M3-10 (`out/` leftovers) was not listed on disk in this pass.
- **Kimi F3:** the silent catch exists, but it is not a D37 breach. `TokenStakingTarget.sol` is outside the D16 set named in the plan. Agree with Kimi's own "no assigned broken requirement." Do not add it to the APEX blocker list.
- **Kimi F4:** the same dangling `lib/crane/.grok/skills/` targets were reported by search tools in the Grok first pass. Agree as hygiene. Disagree that it is an APEX money-path defect or a reason by itself to change the readiness verdict.

## Evidence that changes my view

The first pass left test quality and several D16 bodies unverified. Re-reading peer citations changes that:

- R2.4 is not met by the custody adversarial and fuzz tests that were re-read, and the bare-revert scanner does not select those files unless they contain an APEX marker (`scripts/apex_bare_expectrevert_scan.sh:14–21`).
- Matrix rounding controls in all seven `*SeMatrixBehavior.sol` files catch every revert and can pass on unchanged balances.
- The cited V3 R3.3 supplement does not create an independently moved stale reserve.
- `StandardExchangeRateProviderFacet._getRate` adds a remaining-gas soft `quoteState` probe that falls through on failure. Absence of `try`/`catch` is not D48 conformance.
- Current V4 FullSpread hookless Common is a split implementation with `operationScope` (`UniswapV4FullSpreadHooklessStandardExchangeVaultCommon.sol:51–83`). The September handoff does not map that tree.
- `docs/audits/apex-2026-09-17-evidence.md` has no match for `UniswapV4DetfCommon` or `AlignmentNotAchievable`. That raises confidence that those catches are not recorded exceptions in the evidence narrative. Other JSON under the evidence directory was not exhaustively searched for a later ruling.

No original finding is withdrawn. The cited code still supports findings 1 and 2.

## Corrections to the Grok first pass

- The first pass said an APEX-filename search found no bare `vm.expectRevert()`. That search result stands. It does **not** mean R2.4 holds. Custody files outside that filename filter use bare `expectRevert()` (Astra-01, confirmed).
- The first pass treated "no `catch (` under rate providers" as only a negative search. That negative search still stands, and it is insufficient. Astra-05 is a soft dependency path without `try`/`catch`.
- Matrix completion remains unverified as an execution result. The documentary counts are now known to conflict (follow-up 195/1/7 versus `r12-gating.json` 175 cells: 165/3/7). That conflict is observed, not resolved.

## Peer finding dispositions

### Astra-01 — agree

Re-checked:

- `test/foundry/spec/protocols/staking/rebasingVault/RebasingAwareERC4626_Adversarial.t.sol:38–44`: `test_ADV_cannotBurnOtherHolderViaInternalSy` uses bare `vm.expectRevert()` and calls SY `redeem` as `bob` with `burnFromInternalBalance=true`.
- `RebasingAwareStandardYieldTarget.sol:57–59`: that flag calls `requirePretransferCaller` before the burn. A code-less `bob` fails the EOA guard. The test does not reach the named "cannot burn another holder's shares" check.
- Same file `:112–124`: reentrancy test uses bare `vm.expectRevert()` and does not assert a nested-guard selector.
- `RebasingAwareERC4626_Fuzz.t.sol:55–85`: short exact-out uses bare `vm.expectRevert()`. The success path asserts only `paid == need`.
- `scripts/apex_bare_expectrevert_scan.sh:14–21`: roots are the hook tree, the Uniswap exchange tree, and spec files whose text matches an APEX marker. These custody files are not in the fixed roots.

Impact class: false-positive coverage. This does not show the production guard is missing. `test_ADV02_insufficientSharePretransferReverts` at lines 97–109 is a separate, correctly pinned contract-caller control. It does not repair the mis-aimed test.

### Astra-02 — agree

Re-checked `UniswapV4StandardExchangeWeightedBufferHook_SeMatrixBehavior.sol`:

- `:207–216`: `_roundingToZeroControl` catches every revert and passes if two balances are unchanged. Rollback makes that true for any revert. No assertion that a zero-output branch was reached.
- `:177–194`: partial-consumption checks a range (`assertGe` / `assertLe`) for the booked increase, not an exact consumed-versus-booked reconciliation.
- `:236–258`: exact output and `fatMax - used` refund are real assertions. The SE-share check is only `assertLt` (strict decrease), not "burned only what was used."
- `:369–383`: AMM separation does not require `reservedFace > 0` before the other-token deposit. The ending check is `assertGe` against the starting book.

`catch {` is present in all seven hook `*SeMatrixBehavior.sol` files (weighted 213, dual 305, single non-CP 281, single-CP 274, Balancer quad 326, curve quad 274, orbital 296). The other six bodies were not re-read line by line. Agreement on the weighted file is high. Agreement that the same catch-all shape exists in the other six is high for the catch, medium for identical assertion weakness.

### Astra-03 — agree

Re-checked `UniswapV3FullSpreadStandardExchangeVault_ReserveReconcile.t.sol:58–152`.

- Test 1 sets `total = local + deployed` from current reads and checks `reserveOfToken == localReserve`. That is not a historical stored-total versus live deployed mismatch.
- Test 2 checks a dust-bounded empty sleeve and positive deployed balances. It does not compare those values to a stale stored total.
- Test 3 trades through `vault.exchangeIn`, then asserts the book equals custody. That vault call is not an independent pool trade that leaves the book stale.

This refutes the cited supplement as R3.3 closure. It does not reintroduce 001-M. Other FullSpread tests may cover part of R3.3; that map was not completed.

### Astra-04 — agree

Re-checked:

- `ReceiptBackedERC4626AccountingLib.sol:54–70`: both `sharesFromReceiptUnits` and `receiptUnitsFromShares` use floor division.
- `ReceiptBackedERC4626Target.sol:67–80`: `maxWithdraw` takes the floor asset entitlement, capped by held receipts. `maxRedeem` converts that asset cap back to shares with another floor, then caps by balance.
- `:162–166`: `redeem` rejects shares above `maxRedeem`.

When the share/receipt ratio is not integral, the second floor can make `maxRedeem` smaller than the owner's balance even if `previewRedeem` of that balance is within held receipts. Severity Low is right: liveness / stranded dust, not a theft finding. No runtime case was executed. Confidence high on the two floors; medium on how often a real rate hits the gap.

### Astra-05 — agree

Re-checked `StandardExchangeRateProviderFacet.sol:69–88` and `:172–185`.

`_safePreviewExchangeIn` matches the D48 exact-length staticcall rule: failed or non-32-byte data returns `(false, 0)`. `_getRate`, when state is empty and the subject reports unlock-context support, attempts `quoteState` only if remaining gas clears a threshold, forwards a reduced stipend, and on failure keeps the live-supply path. The comment states that failure must not revert. D48 does not authorize that extra soft snapshot. D60 does not, in the decisions read, authorize a gas-dependent valuation fork.

Financial exploitability was not established. Requirement deviation is observed. This is additional to Grok findings 1 and 2, not a replacement.

### Astra-06 — agree

Re-checked `UniswapV4FullSpreadHooklessStandardExchangeVaultCommon.sol:51–83`. Current hookless Common imports separate inventory, protection, transition-planner, quote, and execution-context units and wraps work in `operationScope`. The plan's former single V4 Common path is not this file. The evidence header and follow-up still attest the September snapshot. No current snapshot-to-variant map was found in the sections read. A prior green run cannot be assumed to cover this tree. This does not prove the refactor is unauthorized.

### MiniMax verdict — disagree

**Not ready**, not ready-with-documented-residuals.

MiniMax's inspected positives (`LocalCreditLib`, custody guard lines, orbital `_unbookedBalance`) are consistent with the Grok first pass and are not withdrawn. They are not the whole D16 set. Using `independent-completion.json` (34,909 / 0, 195 matrix rows, 33 campaigns) as a readiness reason conflicts with the instruction not to treat that JSON as proof, and with the confirmed defects above.

### MiniMax F-APEX-M3-01 — agree as residual, not as a fix failure

Live chain-4663 instances are out of source scope. Evidence text distinguishes replacement verified from deployment remediated. Agree. Do not treat this as a reason the source tree is ready, and do not treat it as an unimplemented source fix.

### MiniMax F-APEX-M3-02 — agree

D12 is an accepted limitation. `LocalCreditLib.requirePretransferCaller` only checks bytecode. Booked inventory is not what that residual pays. Do not demand a code close. Crane NatSpec was still not re-read.

### MiniMax F-APEX-M3-03 — disagree / unverified

Fork artifacts were not opened. The follow-up claims R4.2 / R4.3 / R4.5 passed in a fork session. MiniMax's PARTIAL citation is an earlier ledger sentence. Disposition: **unverified**, not an open PARTIAL finding.

### MiniMax F-APEX-M3-04 — agree

Follow-up record lines 38 and 108: 195 compatible, 1 incompatible, 7 deprecated. `docs/audits/apex-2026-09-17-evidence/r12-gating.json` note: 175 cells, 165 compatible, 3 incompatible, 7 deprecated. The documents disagree. Current matrix files were not counted. This supports Grok finding 3. It does not identify which count, if either, matches the tree today.

### MiniMax F-APEX-M3-05 — agree as documentation, not as a new defect

Owner-ruled tolerance bands are recorded in the plan (D54–D66). They are not silent. Whether current tests still use a band after D55 was not re-read except for the weaker matrix assertions in Astra-02. Do not treat a documented band as an undocumented defect.

### MiniMax F-APEX-M3-06 — unverified

ERC-4626 and Morpho burn sites were not opened in this cross-review. Do not adopt the speculation that a site is uncorrected.

### MiniMax F-APEX-M3-07 — disagree as a defect

D41, D48, and D49 are locked exceptions. Confirming they exist is not a finding that D37 was broken by those probes. The unlisted soft path is Astra-05. The unlisted catches are Grok 1 and 2 / Kimi F1 and F2.

### MiniMax F-APEX-M3-08 — unverified beyond Astra-02

The weighted exact-out row's SE-share assertion is weaker than "burned only used" (Astra-02, confirmed). F6 1% / 2% hook tolerances were not re-read. Do not adopt the broader tolerance finding as confirmed.

### MiniMax F-APEX-M3-09 — agree in substance

The ledger's `EVIDENCED` stamp over stale evidence strings is Grok finding 3. MiniMax's 107/0 versus 107/1 sequence was not re-walked. The integrity problem stands either way.

### MiniMax F-APEX-M3-10 — unverified

Stale `out/` JSON was not listed in this pass. If present, it is hygiene, not a money-path defect. Do not block on it without a directory listing.

### Kimi F1 — agree; confirms Grok finding 1

Does not change finding 1. Does not withdraw it.

Kimi's lines (572, 604, 628, 642, 664–683, 699) are the same constructs read in the first pass at `UniswapV4DetfCommon.sol:572–578`, `:604–610`, `:628–635`, `:642–649`, `:664–684`, `:699–706`. Empty probe catches return false. Alignment failures defer or park. Other selectors are rethrown. That is still outside D41/D48/D49.

Grep of `docs/audits/apex-2026-09-17-evidence.md` found no `UniswapV4DetfCommon` and no `AlignmentNotAchievable`. Kimi's reservation that an exception might live in the unread evidence narrative is not supported by that file. A ruling buried only in an unread JSON is still possible and was not exhaustively excluded. Severity stays Medium. Confidence that the catches violate the written D37 list is high.

### Kimi F2 — agree; confirms Grok finding 2

Does not change the defect. Does not withdraw it.

`UniswapV4SingleStandardExchangeBufferConstantProductHookClaimLib.sol:248–257` still catches `previewExchangeIn` and returns 0 for `AlignmentNotAchievable`. That is a recognized-error list, which D30 forbids, on a D16 hook library. Kimi rates Low–Medium because the function is a view and does not move funds by itself. Grok retains Medium because a zero quote changes residual-buffering behavior for callers. That severity dissent is narrow and unresolved. The defect is not unresolved.

### Kimi F3 — agree the catch exists; disagree it is in scope

Re-checked `contracts/protocols/staking/token/TokenStakingTarget.sol:452`: `try IDETFFundedRewards(address(claimToken)).synchronizeRewards() {} catch {}`. The plan's D16 staking set is Lido, Rocket Pool, EtherFi, and the rebasing vault, plus named DETF entries. This file is not in that set. Out of scope for D37. A second auditor may still ask. Not an APEX completion blocker from the locked text.

### Kimi F4 — agree as hygiene only

Same dangling skill-mirror targets were reported when repository search traversed `lib/crane/.grok/skills/` in the first pass. No contract impact established. Not independently `stat`ed. Does not change the verdict.

## Updated second-audit readiness

**not-ready**

Unchanged verdict, stronger basis. The first pass was not-ready because D37 catches were observed and the 108-criterion claim was unverified. This cross-review adds confirmed test and provenance defects:

- bare or mis-aimed custody negatives the R2.4 scanner misses (Astra-01);
- catch-all matrix rounding controls and weaker-than-named accounting assertions (Astra-02);
- an R3.3 citation that does not create the stale-reserve boundary (Astra-03);
- a gas-dependent rate snapshot fallback outside D48 (Astra-05);
- an unmapped current V4 FullSpread hookless implementation (Astra-06);
- contradictory matrix counts (MiniMax M3-04 / Grok finding 3).

Accepted residuals that remain residuals, not the blockers: D12, live immutable instances, D57 Slipstream deprecation.

What would move the verdict to ready-with-documented-residuals: remove or explicitly lock the DETF and ClaimLib catches; either remove the rate-provider gas fallback or attach a decision and tests; replace the weak custody and matrix controls with exact errors and exact deltas; remap current V4 artifacts and regenerate source-bound evidence; reconcile the matrix and acceptance ledgers to the tree being submitted. That work is not done in the tree as reviewed.

## Remaining dissent

- MiniMax's ready-with-documented-residuals verdict. The documented residuals are real and are not the blockers. The blockers are confirmed source and test defects plus unverified completion claims that MiniMax treated as closure.
- Kimi F2 severity (Low–Medium versus Medium). The code disagreement is none.
- Kimi F3 as an APEX finding. Existence agreed; scope disagreed.
- MiniMax M3-03, M3-06, M3-08, and M3-10 remain unverified or not adopted. They are not counter-evidence to not-ready.
- No peer supplied source that withdraws Grok findings 1, 2, or 3.

Original findings stay attributed to `grok-original.md`. This cross-review does not replace them.
