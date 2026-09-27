# MiniMax M3 requirements question — APEX 2026-09-17 remediation PRD

- **Reviewer:** MiniMax M3 (`minimax/MiniMax-M3`), independent first-pass and cross-review
  reviewer.
- **Question:** Are there any open items to resolve, or questions to clarify the requirements,
  before an implementer can execute the draft remediation PRD without inventing product law?
- **Method:** Re-read the draft PRD at
  `docs/reviews/apex-2026-09-17-remediation-council/REMEDIATION_PRD.md` end-to-end. Cross-check
  each RC's corrections and acceptance criteria against the cited source lines that were already
  read in this review session. Identify items that fall into one of three buckets:
  - Owner decision required (would change the correction or the acceptance test).
  - Already answered by the existing PRD or plan (no new ruling needed).
  - Implementer detail that does not need a new ruling.
- **Out of scope:** Already-deployed instances, migration, registry disablement, historical
  fork replay, live-instance inventory. Preserved Uniswap V3/V4 trees as the bytecode for a
  new deployment. Per the owner follow-up in the draft PRD.

---

## Owner decision required

None.

Each "If... then..." branch in the PRD's acceptance criteria is bounded by current code
behavior. The implementer can execute without inventing product law.

The only place a hypothetical product-law fork could arise is RC-03's acceptance #2:
"If product law instead excludes aToken from holder backing, both the adapter and the SE
exclude it, and aToken is not silently booked into a holder-facing total." This is a
hypothetical fork the PRD author already pre-answers ("both the adapter and the SE exclude
it"). The implementer follows the current default (aToken in expected-hold, both surfaces
include aToken) without an owner ruling.

---

## Already answered by the existing PRD or plan

Each item below cites the PRD section or plan that already answers the implementer's
question.

1. **RC-01 reentrancy guard scope — entire operation** —
   `REMEDIATION_PRD.md:71-83` says "Both money entries reject reentry from funding through
   approval reset, router return, refund, payout, and reserve sync." No new ruling needed.
2. **RC-01 approval cap = operation budget, not infinite** —
   `REMEDIATION_PRD.md:79` says "An approval opened for an operation is limited to the
   amount that route will spend, and is cleared before the call returns, including on
   revert." No new ruling needed.
3. **RC-01 D32 carve-out preservation** — `REMEDIATION_PRD.md:83`: "Do not enable public
   pretransfer on D32 surfaces." D32 surfaces (Aave Cross-Version Loop,
   `BalancerV3PoolStandardExchangeTarget`) are not affected.
4. **RC-02 exact-output delivery equals accounted amount** —
   `REMEDIATION_PRD.md:91-97` spells out the recipient-delta assertion. The Stata
   `_payUnderlying` at `contracts/protocols/lending/aave/v3.6/AaveV3StataStandardExchangeCommon.sol:87-97`
   already uses `withdraw(shortfall, to_, address(this))` (exact-asset). Only the
   ERC-4626 `_payUnderlyingLocalFirst` at
   `contracts/vaults/standard/erc4626/ERC4626StandardExchangeCommon.sol:80-92` needs the
   fix. The PRD cites both files but the Stata file already follows D15.
5. **RC-02 booked-remainder behavior** —
   `REMEDIATION_PRD.md:94-95`: "Any redemption remainder stays booked on the SE, or the
   route uses an exact-asset withdrawal whose share charge matches the preview." The existing
   `_syncAllExpectedHoldReserves` at `BasicVaultCommon.sol:42-52` already books the
   post-settlement balance. No new rule needed.
6. **RC-03 aToken inclusion policy** —
   `REMEDIATION_PRD.md:108-110`: aToken is in expected-hold per
   `AaveV3StataStandardExchangeDFPkg.sol:245-258` (current behavior). The PRD's acceptance
   #1 mirrors this. The conditional #2 is hypothetical and pre-answered.
7. **RC-03 no second share ledger** —
   `REMEDIATION_PRD.md:112`: "Do not add a second share ledger." Clear.
8. **RC-03 no Aave LM reward forwarding change** —
   `REMEDIATION_PRD.md:112`: "Do not change Aave liquidity-mining reward forwarding to
   `feeTo` (`AaveV3StataStandardExchangeCommon.sol:182-198`)." Clear.
9. **RC-04 comment-edit scope** — `REMEDIATION_PRD.md:128`: "No executable refund, fee,
   or pull change is made solely to match a stale comment." Comments only.
10. **RC-04 preserved Uniswap source** — `REMEDIATION_PRD.md:129`: "Do not edit preserved
    historical Uniswap source." The FullSpread README at lines 32-38 is in scope; the
    Uniswap V3/V4 trees under `contracts/protocols/dexes/uniswap/{v3,v4}/` are out.
11. **RC-05 deletion-or-redirect choice** —
    `REMEDIATION_PRD.md:139-141`: "The unused function is deleted, or it calls the same
    guarded pull and refund helper as the installed SE target." Implementer choice.
12. **RC-05 installed selectors unchanged** —
    `REMEDIATION_PRD.md:141`: "Installed selectors and the production diamond cut do
    not change if the function is not currently exposed." DFPkg line 215 confirms
    `SE_FACET` is the production cut.
13. **RC-06 return-truthful-or-remove choice** —
    `REMEDIATION_PRD.md:152-154`: "The returned share count equals the shares the SE
    pulled, measured by the SE return or by the share-balance delta around the call, or
    the unused return is removed and every caller is updated." Implementer choice.
14. **RC-06 approve-to-cap and approve-back-to-zero preserved** —
    `REMEDIATION_PRD.md:155`: "The existing approve-to-cap and approve-back-to-zero
    sequence remains." Clear.
15. **RC-07 `_unbookedSurplus` deficit returns zero** —
    `REMEDIATION_PRD.md:165-166`: "Every live D16 refund path that calls
    `_unbookedSurplus` returns zero credit when balance is below book, and does not pay
    booked inventory." The fix is at
    `contracts/vaults/basic/BasicVaultCommon.sol:33-36`. The PRD lists `_refundExcess`
    at line 120-135 as a shared caller; fixing the helper fixes both.
16. **RC-07 base pull guard or named-entry-test** —
    `REMEDIATION_PRD.md:167-168`: "Either the base pull enforces the contract-caller
    check when `pretransferred` is true, or a test names each D16 public entry and shows
    it cannot reach the unguarded base branch." Implementer choice.
17. **RC-07 historical consumers out of D16** —
    `REMEDIATION_PRD.md:169`: "Historical consumers outside the D16 override set are
    listed before any base-helper edit." Currently every D16 caller either overrides the
    pull or calls a name-respaced helper. No list-edit required.
18. **RC-08 named error not weakening comparison** —
    `REMEDIATION_PRD.md:182-183`: "Do not weaken the backing comparison. Do not change
    refund amounts on this route." Clear.
19. **Accepted product law** — `REMEDIATION_PRD.md:61-67` lists D12/D28, D44, D32, D6,
    preserved Uniswap. The implementer does not "fix" any of these away.
20. **D12 explicit D28 restated** — `REMEDIATION_PRD.md:64, 207`: "D12 non-atomic contract
    pretransfer is confirmed as implemented and accepted. It is not a finding."
21. **Audit disposition** — `REMEDIATION_PRD.md:185-199` covers all eight audit items
    (001-M, 001-M2, 003, 008, 009, 004B, 005, withdrawn `beforeSwap`, downgraded weighted
    dust) with the disposition labels corrected per the PRD's R1.2 states (`WITHDRAWN`,
    `Downgraded to informational`).
22. **Test coverage and shared rules** — `REMEDIATION_PRD.md:221-241`. Eight rows
    name the suite to extend; the rules forbid `expectRevert` placeholders, mocks of the
    subject, loosening expected amounts, and `via_ir`.
23. **Severity dissenting opinions** — `REMEDIATION_PRD.md:208-210` records the
    High/Medium/Low dissents and applies a chosen level. The PRD's chosen levels are
    binding for the implementation.
24. **Functional dissent on RC-06** — `REMEDIATION_PRD.md:210`: "MiniMax says the unused
    return is not a defect. The requirement is limited to making the return truthful or
    removing it." Closed.
25. **Owner follow-up scope** — `REMEDIATION_PRD.md:54-55`: already-deployed instances
    out of scope, fresh deployments are the release unit, preserved Uniswap V3/V4 trees
    not the bytecode for a new deployment.

---

## Implementer detail that does not need a new ruling

Each item below is a concrete choice the implementer can make from the PRD's acceptance
criteria and the cited source. None requires a new owner ruling.

1. **RC-01 callback-capable token fixture choice** — ERC-777 (`tokensToSend` /
   `tokensReceived`) or ERC-1363 (`onTransferReceived`) both qualify. PRD
   `REMEDIATION_PRD.md:82` says "A callback-capable token fixture is allowed." No
   specific token standard is mandated.
2. **RC-01 approval replacement** — replace `type(uint256).max` in
   `_approvePermit2ToRouter` at
   `contracts/protocols/dexes/balancer/v3/pools/BalancerV3SinglePoolStandardExchange.sol:271-275`
   with the operation budget (`actualAmountIn` for `exchangeIn`, `quotedUsed` /
   `amountIn` for `exchangeOut`). Reset to 0 before any external call, including on
   revert. PRD `REMEDIATION_PRD.md:79-80` makes this explicit.
3. **RC-01 test entry-point coverage** — "funding through approval reset, router return,
   refund, payout, and reserve sync" (PRD `REMEDIATION_PRD.md:78`). The implementer
   picks how many separate tests cover these six entry points.
4. **RC-02 fix scope is the ERC-4626 SE Common only** — the only `redeem(previewWithdraw(...))`
   call in the production tree is at
   `contracts/vaults/standard/erc4626/ERC4626StandardExchangeCommon.sol:88`. The Stata
   `_payUnderlying` at `AaveV3StataStandardExchangeCommon.sol:87-97` already uses
   `withdraw(shortfall_, to_, address(this))`. The PRD cites both files but the
   implementer fixes only the ERC-4626 file.
5. **RC-02 alternative — exact-asset `withdraw`** — PRD `REMEDIATION_PRD.md:95`: "or
   the route uses an exact-asset withdrawal whose share charge matches the preview."
   Implementer may use `vault.withdraw(shortfall, recipient, address(this))` instead of
   splitting redeem-then-pay-local.
6. **RC-03 backing helper location** — implementer may copy
   `_bookedATokenEquiv` from `ReceiptBackedERC4626Target.sol:191-198` into the Stata
   Common, or call the shared adapter's helper directly. PRD does not require a specific
   location.
7. **RC-03 helper behavior on no-aToken** — the helper iterates `_vaultTokens()` and
   skips `receipt` and `underlying`. If aToken is not in `_vaultTokens()` (e.g., it was
   not registered as expected-hold by the DFPkg), the helper returns 0 naturally. PRD
   `REMEDIATION_PRD.md:109` aligns the two surfaces on this.
8. **RC-04 comment text** — the PRD's RC-04 acceptance #1 lists the executable rules the
   comments must describe. The implementer writes the new NatSpec paragraphs to match
   those rules. PRD `REMEDIATION_PRD.md:125-128` lists the rules.
9. **RC-04 README text** — the PRD's RC-04 acceptance #1 lists the pull semantics the
   README must describe. The implementer writes the new README prose. PRD
   `REMEDIATION_PRD.md:125-128`.
10. **RC-05 deletion vs redirect choice** — "Either the unused function is deleted, or
    it calls the same guarded pull and refund helper as the installed SE target." PRD
    `REMEDIATION_PRD.md:139`.
11. **RC-06 return source choice** — "measured by the SE return or by the share-balance
    delta around the call, or the unused return is removed and every caller is updated."
    PRD `REMEDIATION_PRD.md:152-154`. The SE's `exchangeOut` returns the share count
    consumed.
12. **RC-07 deficit-safety implementation** — implementer may use checked subtraction
    (`uint256 bal = ...; uint256 book = ...; return bal > book ? bal - book : 0;`) or
    Solady's `unchecked` pattern with an overflow revert; both are acceptable. PRD
    `REMEDIATION_PRD.md:165-166` only specifies the behavior.
13. **RC-07 base-pull guard implementation** — if implementer chooses option (a), the
    guard fires inside the base `_secureTokenTransfer` when `pretransferred` is true.
    Every current D16 caller already calls `LocalCreditLib.requirePretransferCaller`
    before `_secureTokenTransfer`, so the duplicated call is a no-op (it reverts on EOA
    callers that would have already reverted). PRD `REMEDIATION_PRD.md:167`.
14. **RC-08 named error wording** — PRD `REMEDIATION_PRD.md:178-179` requires "a named
    error carrying both compared values." Implementer chooses the name
    (e.g. `PassThroughZapOutUnderwaterLP(uint256 poolBalance, uint256 vaultLpReserve)`).
15. **Test file structure** — PRD `REMEDIATION_PRD.md:226-234` names specific existing
    suites per RC. The implementer extends those suites; no new suite is mandated.
16. **Callback token fixture in RC-01** — any token with `transferFrom` /
    `safeTransferFrom` callbacks (ERC-777, ERC-1363, mock with hook receiver) qualifies.
    PRD `REMEDIATION_PRD.md:82`.
17. **RC-02 orbital unwrap test selection** — the implementer picks "one orbital capped-unwrap
    route that uses this SE" in the existing orbital suite. PRD `REMEDIATION_PRD.md:228`.
18. **RC-03 control test funding** — a "funded control with nonzero booked aToken" can be
    set up via `depositATokens` from the shared adapter, or via a direct transfer to the
    vault followed by `_syncAllExpectedHoldReserves`. PRD `REMEDIATION_PRD.md:110`.
19. **Whether RC-05 deletion requires updating other contracts** — the PRD
    `REMEDIATION_PRD.md:141` says "Installed selectors and the production diamond cut
    do not change if the function is not currently exposed." The DFPkg is not touched.
20. **Whether the implementer must also rename the unused `_refundPairDust` `to` parameter**
    — the PRD does not require this. The current silent `to;` is informational.

---

## Open items to resolve with the human

None. The draft PRD's `Required outcome` section, the eight RC entries, the `Audit
disposition` table, the `Test coverage` table, the `Shared test rules`, the `Dissent and
items that are not requirements` section, and the `Accepted product law that must not be
"fixed" away` block are sufficient to execute. The implementer can pick the bounded
"Either... or..." branches per the PRD's text without inventing product law.

If the owner wants to reopen any of the following, a new ruling would be needed; they are
NOT open today:

- Migration of already-deployed instances (out of scope by owner follow-up;
  `REMEDIATION_PRD.md:54-55`).
- Live-instance inventory for APEX-2026-001-M2 (out of scope by owner follow-up;
  `REMEDIATION_PRD.md:54-55`).
- Whether aToken should be removed from Stata expected-hold (PRD's RC-03 conditional #2
  pre-answers: "both the adapter and the SE exclude it"; no current ask).
- Whether `_payUnderlyingLocalFirst` should also be re-examined in Stata
  (PRD's RC-02 cites the Stata file but the Stata `_payUnderlying` already uses
  `withdraw`; no change needed).

---

## Reviewer notes for the coordinator

- The draft PRD is complete. Each RC names file/line, intended behavior, broken invariant,
  acceptance criteria, non-goals, and attribution. No new owner ruling is required to
  execute.
- The audit disposition labels are now consistent with the PRD's R1.2 states
  (`WITHDRAWN`, `Downgraded to informational`, `Refuted in current replacement source`,
  `Out of scope`). The first-pass "accepted residual" labels for the withdrawn
  `beforeSwap` and downgraded weighted-dust findings were corrected in cross-review and
  preserved here.
- The implementation plan's locked D1–D55 plus the follow-up D56–D69 are not reopened
  by this PRD. Plan completion claim is not treated as proof.
- No forge tests, chain reads, deployments, or broadcasts were run in this round. I do
  not write the final remediation PRD or edit source, tests, config, or scripts.
- I did not re-read any peer files (`docs/reviews/` peer files or other reviewers'
  outputs) per the prompt instruction.

Saved to `/Users/cyotee/Development/projects-defi/daosys/lib/indexedex/docs/reviews/apex-2026-09-17-remediation-council/minimax-requirements.md`.