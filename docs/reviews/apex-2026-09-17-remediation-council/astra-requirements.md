# Astra — requirements readiness follow-up

## Answer

**The correction policy is largely executable without inventing product law. I found no need for a new economic or deployment-scope ruling. There is one conditional acceptance-policy question for RC-08, plus wording that should be reconciled with decisions already made.**

In particular, whether Stata counts already-booked aToken is **already answered**: it must count it. The draft's alternative exclusion language must not be read as permission for an implementer to choose different economics.

The RC-08 question need not block implementation or the search for a production-route regression. It becomes a release-acceptance blocker only if the implementer cannot legitimately reach the defensive check under the permitted fixture rules. Do not declare that branch unreachable without evidence.

I read the current `REMEDIATION_PRD.md` only, not the linked reviewer artifacts or other reviewers' outputs. I also checked relevant existing requirements and production source. No source, tests, configuration, or scripts were edited or executed. Only this assigned report was written. References to **Draft** below mean `docs/reviews/apex-2026-09-17-remediation-council/REMEDIATION_PRD.md` as read in this turn.

## 1. RC-03: inclusion of already-booked aToken

**Classification: already answered by the existing PRD or plan.**

- Draft RC-03, lines **105–111**, requires shared backing but also says, conditionally, that both interfaces could exclude aToken if product law excludes it. The test row at **229** repeats “included, or excluded.”
- Existing authority is explicit: `docs/audits/apex-2026-09-17-remediation-and-regression-tests.md:249` says: **“Stata also counts any already-booked local aToken value at its underlying-equivalent accounting value.”** It also expressly forbids treating this as authorization to retain new aToken input instead of using `depositATokens`.
- Source registration supports that requirement: `contracts/protocols/lending/aave/v3.6/AaveV3StataStandardExchangeDFPkg.sol:245–258` includes aToken in the expected-hold set. The shared adapter counts its book at `contracts/vaults/standard/erc4626/ReceiptBackedERC4626Target.sol:183–198`.

**Execution instruction:** Include the already-booked aToken term consistently across the required Stata interfaces. Do not choose exclusion as an equally valid implementation. The coordinator can remove or label the draft's exclusion branch as requiring a future, explicit override. No human question is needed unless the owner actually intends to reverse the existing ruling.

## 2. RC-03: accounting consistency does not authorize a new aToken investment policy

**Classification: already answered by the existing PRD or plan.**

The prior PRD at **238,249–250,254** preserves the existing aToken wrapping route, common valuation, actual receipt payout limits, fee differences, and existing investment/sweep triggers. Draft RC-03 at **111–112** preserves receipt limits and reward economics.

**Execution instruction:** Correct backing math and projections without introducing a new retained-aToken deposit mode, new public sweep, fee policy, or receipt substitution. Include underlying-equivalent aToken value in accounting; preserve the real liquidity constraints of each payout route. A shared backing function does not imply that every route can deliver every form of backing. Helper placement and reuse are implementer details.

## 3. RC-01: allowance cleanup on revert

**Classification: implementer detail that does not need a new ruling.**

Draft RC-01 at **78–82**, especially **79**, says allowance is cleared “including on revert.” The test row at **227** distinguishes rollback on failure from zero allowances on success. Current approval setup/reset is at `contracts/protocols/dexes/balancer/v3/pools/BalancerV3SinglePoolStandardExchange.sol:262–275`.

**Required interpretation:** A reverted transaction restores the pre-call allowance state; it cannot persist a cleanup performed inside that reverted transaction. For a fresh corrected deployment whose entry allowance is zero, rollback therefore leaves zero. Successful operations explicitly clear their temporary allowances. Acceptance should assert **unchanged entry state on revert**, not demand a cleanup that survives rollback or introduce catch-and-continue behavior.

The coordinator should clarify that sentence, but no product choice is missing.

## 4. RC-01: lock choice and finite approval budgets

**Classification: implementer detail that does not need a new ruling.**

Draft RC-01 at **75–83** already requires a shared operation-wide lock, finite operation-scoped approvals, preserved supported routes, and unchanged D12 semantics. The current route establishes funding/spend bounds at `BalancerV3SinglePoolStandardExchange.sol:151–168,180–188`.

**Execution instruction:** Select an appropriate existing guard and exact named error; cover both entries and all external-call windows. Use approvals bounded by the route's authorized spending budget, never blanket maximum approvals. Preserve false-flag quoted-use funding and true-flag bounded credit. Do not redefine a slippage maximum as authenticated payment. The implementation must show which bound is passed to the router and approval helpers; no new owner economics decision is needed.

## 5. RC-02: exact withdrawal versus redeem-to-self

**Classification: already answered by the existing PRD or plan.**

Draft RC-02 at **90–98** explicitly permits exact-asset withdrawal or redemption into the SE followed by exact payout and retained remainder. The current mismatch is `contracts/vaults/standard/erc4626/ERC4626StandardExchangeCommon.sol:80–92`.

**Execution instruction:** Either correction is allowed if recipient delivery, preview/share charging, returned output, and final reserve booking satisfy the stated assertions. No owner needs to choose the internal mechanism. Rounding surplus must not go to the caller or `feeTo`, and the orbital callback must not acquire operation-created surplus. Keep pre-existing D12 face separate in tests.

## 6. RC-05: remove the duplicate money implementation, not merely one unsafe refund statement

**Classification: already answered by the existing PRD or plan.**

Draft RC-05 at **139–142** permits deletion or canonical-helper consolidation and says source must not retain a second public money implementation. The old abstract target also contains an unauthenticated true-flag `exchangeIn` path at `contracts/hooks/uniswap/v4/standardExchange/constantProduct/single/UniswapV4SingleStandardExchangeBufferConstantProductHookTarget.sol:695–724`, in addition to the cited `exchangeOut` at **736–754**.

**Execution instruction:** Apply the stated single-implementation requirement to both duplicate money entries. Preserve installed selectors and cuts. Deleting uninstalled dead functions is an explicitly allowed structural correction; do not add an otherwise unnecessary production exposure solely to obtain a runtime red test.

## 7. RC-05/RC-06: structural corrections and the general red/green rule

**Classification: already answered by the existing PRD or plan.**

The general red/green statement is at Draft **59,223,238**, but the specific acceptance rows expressly permit:

- RC-05 deletion plus source inspection and unchanged production surface tests (**138–142,231**).
- RC-06 removal of the unused return plus existing unwrap/allowance assertions (**149–155,232**).

**Execution instruction:** Follow those specific alternatives. No public getter, selector, event, or test-only production entry is required merely to observe an unused internal return. If retaining the return, use the stated truthful-spend requirement. If removing it, prove source/caller consistency and preserved production behavior. The coordinator should explicitly identify these as structural-evidence exceptions to the general runtime red/green wording; this is reconciliation of existing choices, not a new ruling.

## 8. RC-07: preserve historical semantics and distinguish credit failure from refund saturation

**Classification: already answered by the existing PRD or plan.**

Draft RC-07 at **162–169,233** requires saturating availability on active D16 paths, guard coverage, historical-consumer preservation, and permits a direct helper test when no production route can create a deficit. The older plan at `docs/audits/apex-2026-09-17-remediation-and-regression-tests.plan.md:212` explicitly directs new rules through D16 consumers rather than changing historical inherited behavior.

The shared implementation is at `contracts/vaults/basic/BasicVaultCommon.sol:34–35,77–102,120–135`.

**Execution instruction:** Trace consumers before editing shared code. A credit request above zero available credit must fail with the applicable insufficient-credit error. A custody-bound refund calculation saturates at zero; do not invent a universal insolvency recovery or new forced payout rule. If the deficit cannot be produced on an allowed production route, RC-07 already provides a helper-test alternative. No new ruling is required.

## 9. RC-08: evidence fallback if the defensive backing branch cannot be reached legitimately

**Classification: owner decision required — conditional acceptance-policy decision, not a correction-policy decision.**

Draft RC-08 at **176–181** clearly specifies the code correction: retain the comparison and replace the empty revert with a named error carrying both compared values. That does not need clarification.

However, Draft test row **234** unconditionally requires forcing that check to fail on the production route; shared rules at **223,238** require the same runtime red/green assertion without replacing the production subject. Unlike RC-07 at **233**, RC-08 provides no evidence fallback if the invariant cannot be violated through permitted dependencies and setup.

The production branch first validates funding and consumes the computed LP input, then checks remaining LP backing: `contracts/protocols/dexes/uniswap/v2/UniswapV2StandardExchangeOutTarget.sol:488–580`. Reading this control flow does **not** establish either reachability or unreachability of the final failure. No execution was performed in this review.

**Only question for the human:** If the implementer documents that the RC-08 backing-failure branch cannot be reached on an allowed production route without SUT mocking, storage fabrication, or unrelated code changes, may acceptance use a focused test of the actual production check/error plus production-route conservation, rollback where reachable, and funded-success controls, or must RC-08 remain incomplete until a permitted end-to-end trigger is demonstrated?

This changes the required evidence, not the backing invariant. The implementer must first investigate honestly; neither a broad expected revert nor an unrelated earlier failure proves the new error. Without a new ruling, the draft's stricter production-route requirement remains binding. The implementer may not silently adopt the fallback.

## 10. Release scope, deploy selection, and excluded policy changes

**Classification: already answered by the existing PRD or plan.**

Draft owner follow-up **53–55**, accepted law **61–67**, and test constraints **241** settle these points:

- Fresh deployments of corrected source are the release unit.
- Already-deployed instances, migration, historical replay, and live-instance inventory are out of scope.
- Preserved Uniswap V3/V4 sources must not be selected as fresh-deployment bytecode.
- D12/D28 resting credit, D44 delegated-account acceptance, D32 public-pretransfer rejects, and D6 residual retention remain unchanged.

**Execution instruction:** Validate the fresh deployment/artifact selection and installed surfaces using the normal production deployment path. Do not reopen chain inventory or migration. Any necessary source/artifact identity checks and suite selection are implementer details, not reasons for a new product ruling. Explicit implementation authorization remains separately required under Draft **7,59**.

## Handoff conclusion

Before execution, the coordinator should make three non-economic wording reconciliations: remove RC-03's apparent discretionary exclusion option, describe RC-01 revert behavior as rollback, and identify the already-authorized structural evidence alternatives for RC-05/RC-06. These follow existing requirements.

The sole human question is the **conditional RC-08 evidence fallback** above. Everything else identified here is already decided or can be implemented without new product law. The four named RC-03/05/08 test files checked by scoped discovery exist at their draft paths; no missing supplied document was encountered. No tests or deployment actions were run, and no remediation PRD was edited.
