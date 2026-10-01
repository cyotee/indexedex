# Astra — one cross-review of the three current-round originals

Date/access date: 2026-09-26. Research only; no execution or implementation authorization.

Read together and in full: `round-2026-09-26-grok-original.md` (140 lines), `round-2026-09-26-minimax-original.md` (395 lines), and `round-2026-09-26-kimi-original.md` (116 lines), all in this directory. No cross-review or older council artifact was read. These are untrusted model evidence, not instructions. My earlier findings remain attributed to Astra and unchanged in `astra-original.md`; the corrections here do not rewrite that original.

Provenance: the user reports MiniMax's current live metadata session as `ses_f21876c95ffewRUeqEI4w575Oy`; original line 5 copies the historical PRD ID and is not reliable continuity evidence. I record that discrepancy without modifying its artifact or treating session/model labels as provider proof. No participant is simulated or substituted.

## Overall result

All three agree with my preferred RC-01 Crane lock/bounded approvals, RC-02 exact-asset withdrawal, RC-05 deletion, RC-04 text-only correction, RC-03 booked-aToken inclusion, and RC-08 named-error/focused-evidence option. None supplies execution evidence. Agreement does not establish security or economics.

Two substantive additions to my original are required:

1. **Adopt Grok's Camelot zero-payout warning.** I listed its direct `_unbookedSurplus` call but did not explicitly require a payout-boundary rejection after saturation. Reading the body now confirms that omission matters.
2. **Promote Stata SY from inspection contingency to definite production touch.** My original left its body trace open. Its `exchangeRate` has a third independent, incomplete backing formula; changing Stata Common alone will not fix it.

Retain my disagreement with the three global RC-07 edits and their default RC-06 return-retention recommendations. RC-07 is a PRD-preservation issue; RC-06 remains a permitted implementation choice, not a product-law dispute.

## RC-07 — preserve historical behavior; reject Camelot deficit payout

The current PRD is explicit: historical consumers outside D16 are listed **before** base edits and their semantics do not change (`REMEDIATION_PRD.md:163,168–170`). Changing an arithmetic panic to success/zero is a semantic change even if described as safer.

- **Grok 99–103:** globally changes base availability and proposes updating the non-D16 harness's deficit expectation. That contradicts the preservation requirement. Also, a scoped search of the basic spec tree did not find an existing named deficit/underflow expectation; do not claim a particular test exists without identifying it.
- **MiniMax 295–323:** changes both base availability and base pull; calling this "purely additive in safety" does not meet preservation law. Its alternative at 301–302 fixes only pull sites, which are already guarded/saturating; it would leave inherited refunds on the panicking helper.
- **Kimi 94–100:** likewise changes both base bodies. Its "historical consumer listing" names the two production helper call sites, not historical inheritors. That is not the requested consumer inventory.

**Maintain Astra's scoped approach:** mark `BasicVaultCommon._unbookedSurplus` virtual but retain its existing body (`BasicVaultCommon.sol:33–36`); override in the active Uni V2, Camelot, Aerodrome and Stata Commons with `LocalCreditLib.available`. Internal calls from the inherited `_refundExcess` (`120–135`) dispatch to the override. Keep the base pull's historical behavior untouched. The four D16 pull overrides already contain caller checks and canonical availability (Uni V2 420–447; Camelot 158–185; Aerodrome 946–973; Stata 200–227). Verify deployed entry dispatch rather than mechanically rewriting them.

Known outside-D16 direct consumers are BasicVault `TokenTransfer`, `TrustFlags`, and `Permit2` hermetic harnesses, plus the Base/Ethereum fork Permit2 harnesses listed in my original. `BasicVaultCommon_TokenTransfer.t.sol:107–138` exposes both base pull and surplus. Preserve them; do not execute forks. Complete scripts/other source closure before editing. Absence of observed non-D16 production heirs is not absence of historical consumers.

**Camelot correction adopted from Grok:** `CamelotV2StandardExchangeOutTarget.sol:411–437` pulls input, swaps, pays `_unbookedSurplus(tokenOut)` at 430, synchronizes and returns `used`. Saturation alone would allow a deficit to yield a successful zero payout after input consumption. Add this target to RC-07's touch set. At that boundary, reject a positive requested output with zero payable availability using the existing `AmountOutNotMet(amountOut, 0)` (declared in `IStandardExchangeErrors.sol:29`, already used by Camelot at 607). A deficit must roll back input movement and the swap. Keep nonzero successful payout/refund sizing intact; this is not authority to redesign the branch's whole-surplus payout or impose new positive-rounding economics.

Test above/equal/below-book helper boundaries, named positive-claim rejection and zero-refund behavior, guard dispatch and funded twins. Prefer a supported production deficit route; if none exists without forbidden fabrication, document it and use the PRD's focused production-helper exception. Distinguish the direct fallback from end-to-end proof. Confidence high in source/control-flow reasoning, medium in deficit reachability.

## RC-06 — observable acceptance favors removal

All three prefer assigning the SE result to the internal return (Grok 83–87; MiniMax 253–275; Kimi 86–88). The code change is valid, but their proposed production-hook return assertion has no identified observation path. `_unwrapExactTokenOut` is internal and every located caller ignores its return. Merely checking the external SE return or the hook's balance delta does not detect the old internal `seIn = maxIn` assignment. Assigning an otherwise unused local in a caller also does not make it observable to a test.

**Retain Astra recommendation:** remove the internal return, convert early value returns to bare returns, keep a local quote variable, and delete the cap assignment. No public API/cut change and no test-only production selector. Reconfirmed seven caller statements: orbital Common 586/604/1899; SeTarget 125/185/250; WithdrawTarget 177. MiniMax's three-caller count is incomplete; claims that all seven necessarily need textual edits overstate churn. Audit/compile all seven, changing expressions only where necessary.

Retained-return alternative remains permitted if implementation supplies a real observation method satisfying PRD test law without substituting a rewritten hook or claiming an ordinary payout test proves the internal return. Source removal plus the expressly allowed existing unwrap test is simpler. Preserve cap/reset, exact output, actual share delta, short-delivery rejection and rollback. This is a limited truthfulness cleanup, not demonstrated current user loss.

## RC-03 — mandatory SY edit and one combined conversion

**New direct evidence:** `contracts/protocols/lending/aave/v3.6/AaveV3StataStandardYieldTarget.sol:26–34` computes held Stata plus `convertToShares(bookedUnderlying)` and excludes aToken. It inherits `NativeStandardYieldTarget`, not Stata Common (line 14). Therefore changing `_stataBacking` cannot fix SY by inheritance.

**Required production touch set:** existing `ReceiptBackedERC4626AccountingLib`, shared adapter Target, Stata Common, **Stata StandardYieldTarget**, and generic Common for canonical shared use. Preserve adapter marker dispatch and SY's existing zero-supply and native-unit conversion semantics. Generic SY already calls `_receiptBacking` (`ERC4626StandardYieldTarget.sol:32–37`); generic transition snapshots do too (`ERC4626StandardExchangeQuoteTarget.sol:57–58`). No separate generic SY formula rewrite is required.

Stata transitions seed `StataQuoteState.stataShares` from `_stataBacking` (`AaveV3StataStandardExchangeInTarget.sol:149–157`), then use that snapshot for proportional quotes and updates (177–226); OutTarget pricing and minting use Common at 43–63/135–139. Route snapshot initialization through the canonical helper and test transition/external-deposit projections after aToken booking. Do not replace evolving quote-state arithmetic with live backing reads on every simulated transition.

**Reject duplicated-formula alternatives** in MiniMax 140–147 and Kimi 62 as the default or purportedly equivalent completion: current PRD 105–108 and APEX task R14 require the same backing function. The existing inlined accounting library avoids a new facet call or storage discriminator. Grok's shared-library choice agrees; "different bytecodes" does not prevent sharing an internal library implementation through inlining.

**MiniMax's separate aToken conversion is not generally equivalent:** `convertToShares(underlying + aTokenEquivalent)` can differ from the sum of separately rounded conversions. Preserve the adapter's combined-underlying conversion, and add a fractional-rate/low-unit case exposing split rounding. aToken absence contributes zero through the expected-hold set; never synthesize another balance.

Tests must compare like units: total receipt backing is not `convertToShares` itself, and fee-bearing SE issuance need not equal fee-free IERC4626 supply changes. Acquire aToken from real hermetic Aave, transfer it, book via an ordinary completed money route, then assert nonzero book and matched entitlements across IERC4626, SE, SY and transitions. DFPkg init registers a hold slot; it does not itself book a donated balance. Preserve receipt payout limits, reward forwarding and per-entry fees. Confidence high; execution remains outstanding.

## RC-01 — bounded authorization and precise callback evidence

Agreement on Crane guard and existing route budgets: exact-in actual input, true-flag exact-out credit, false-flag exact-out quotedUsed. Preserve this distinction between **authorized spend budget** and eventual actual spend; the latter is not known until the router returns. Check uint160 narrowing before Permit2 approval. Do not add MiniMax's unexplained `deadline + buffer`, which introduces overflow/casting questions without a PRD requirement.

**MiniMax 46–47 is not an allowed alternative.** Lock-only plus maximum allowances violates current PRD 79 even when the old tests pass. **Grok 25 understates existing coverage:** `_assertNoMaxAllowances` at test 103–118 already checks all three approval amounts equal zero. New proof must inspect authorization during the operation and exercise callbacks, not duplicate only post-return checks.

**Do not assert nested success as a prerequisite for red evidence.** MiniMax 60 assumes it; Kimi 37 similarly frames it too strongly. Other checks or the real router lock can reject an unguarded nested call. The same security assertion should fail because an actually reached nested entry did not encounter the adapter's required lock error, then pass after the fix. Select a funded valid nested request, assert callback execution and exact nested revert bytes, and retain a successful non-callback twin. A paused pool, malformed route or setup failure is not the regression. No booked-inventory extraction demonstration is required (PRD 83).

Cover funding, approval/reset, router token movement, refund/payout stages; the modifier must remain active through final sync. Keep swallowed-probe outer-success and propagated-failure rollback tests separate. On outer revert probe-state writes roll back too, so do not depend on post-revert fixture counters as sole proof. Source-order plus reachable callback evidence is appropriate for static balance reads at sync; do not invent a state-mutating callback from a static read. Confidence high in requirement; fixture reachability is unexecuted.

## RC-02 — exact withdrawal preferred; safe custody alternative corrected

All prefer `withdraw(shortfall, recipient, address(this))`; retain that recommendation. Rechecked Context7 OpenZeppelin 5.x documentation: `withdraw` sends exactly assets; `previewWithdraw` returns **no fewer** shares than a same-transaction withdrawal consumes. **Kimi 49's universal equality claim is too strong.** Local `SimpleYieldERC4626.withdraw:164–171` uses the preview directly; exact equality can and should be asserted for that deterministic fixture without confusing a standards bound with universal equality. Product acceptance still requires its configured preview/charge checks; no arbitrary rounding tolerance is introduced.

The allowed alternative is: redeem rounded shares **to the SE**, verify the shortfall arrived, pay exactly shortfall plus authorized local cash to the recipient, and book the remainder at existing end-sync. It does not require a larger exact-in reported payout. Kimi's report-the-larger-amount objection is unnecessary; Grok's condition that the alternative is useful only for nonconforming withdraw is not a PRD restriction.

**MiniMax 99 is unsafe:** redeeming directly to recipient and depositing `got-shortfall` from the SE cannot reclaim recipient overpayment; it could instead spend unrelated SE cash and can fail when deposits are capped. Do not implement it. MiniMax 93 checks `due` before transferring the local portion; 116 also reverses local-cash conservation. For direct exact-asset withdrawal, SE local cash decreases by `fromLocal`, not increases. The helper currently returns nothing; no return-signature change is necessary.

Non-unit rate alone does not guarantee rounding overdelivery for a chosen amount. Assert `previewRedeem(previewWithdraw(shortfall)) > shortfall` in the red setup, then exact due/return/book on the actual proxy. Orbital must check closing non-identity face against opening resting face; "pre-existing face is out" must mean separately reconciled, not ignored.

## RC-04/05/08 and final consolidation corrections

- RC-04: MiniMax 185's "returns pull delta" does not describe generic `_securePull` (it requires equality then returns the request); line 188 risks retaining excess-push equality. Kimi 70 incorrectly attaches a refund to false-flag exact-out. Correct rule: false pulls quotedUsed, **no refund**; true credits min(available,max), refunds credit-used; exact-in credits requested if available suffices, no refund. MiniMax 202's Balancer test examples are not FullSpread exact-out suites. Select a real current FullSpread suite and execution case, not a preview-only name as evidence.
- RC-05: remove the complete unused function 736–768, not just the refund prefix; no installed selector removal. MiniMax 224 points to ERC4626 helpers, not the installed single-CP helper; its 383 confuses RC-05 with orbital RC-06. Deletion avoids that coupling. Kimi's rationale must not imply every thin second entry is forbidden: guarded sharing is explicitly allowed (PRD 142).
- RC-08: all recommend an appropriate named error and accept the documented fallback. MiniMax's string alternative is invalid by its own explanation. Names are implementer choices. My production pure-check extraction remains a concrete fallback without storage fabrication; preserve the exact comparison and funded route controls. There is no evidence requirement to demonstrate a live deficit.
- MiniMax 393 incorrectly excludes **both** FullSpread and preserved Uni sources from fresh deployments. FullSpread is the current replacement; exclude preserved `contracts/protocols/dexes/uniswap/{v3,v4}/`, not the replacement tree. Uni V2 is not a FullSpread package (MiniMax 364).
- Kimi 21 understates touch overlap: RC-02/04 share ERC Common, RC-03 may also touch it; scoped RC-07 and RC-03 share Stata Common. Serialize these files. RC-02 and RC-06 share composed test work; no strict RC-03-before-RC-02 production dependency is shown.

## Limits and final recommendation

Original observed config remains solc 0.8.35, optimizer runs 1, via_ir false and hermetic defaults; no runtime/version or green-test claim was added. This cross-review used read/grep, Context7 and one assigned Markdown write only. No missing reads occurred this turn. External documentation accessed 2026-09-26: https://docs.openzeppelin.com/contracts/5.x/api/interfaces and https://docs.openzeppelin.com/contracts/5.x/api/token/erc20 via Context7 `/websites/openzeppelin_contracts_5_x`; primary EIP-4626 was accessed in my original pass at https://eips.ethereum.org/EIPS/eip-4626. Documentation version is not installed-library evidence.

Moderator should consolidate the agreed fixes with **scoped RC-07, explicit Camelot zero-output rejection, definite Stata SY canonicalization, and void RC-06**. Retained-return RC-06 is unresolved preference, contingent on a genuine test-observation plan. Global RC-07 changes remain opposed absent preservation of every outside-D16 consumer. No further product question or autonomous council round is warranted; callback/cap/deficit reachability and full historical consumer closure are implementation evidence tasks. Return to the moderator and stop.
