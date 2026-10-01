# Remediation PRD: APEX 2026-09-17 council review

- **Status:** DRAFT
- **Date:** 2026-09-25
- **Updated:** 2026-09-25, final clarity pass. No human question remains. Two acceptance sentences were aligned with fixes the draft already allowed.
- **Review target:** Current working-tree production source implementing the APEX 2026-09-17 remediation in this IndexedEx repository. The review was not bounded by the implementation plan. It prioritized value-in, value-out, reserve booking, refunds, share burns, hook custody, and pretransfer caller checks.
- **This document does not authorize code changes.** It is a handoff. A later session must be explicitly asked to implement it.

## Inputs used

| Input | Path | Role |
| --- | --- | --- |
| Audit report | `docs/audits/APEX-IndexedEx-Audit-2026-09-17.pdf` | Auditor claims to confirm, refute, or leave unverified. Not proof. |
| Remediation PRD | `docs/audits/apex-2026-09-17-remediation-and-regression-tests.md` | Intended behavior, including owner clarifications. |
| Implementation plan | `docs/audits/apex-2026-09-17-remediation-and-regression-tests.plan.md` | Locked decisions and completion claims. Claims, not proof. |
| Follow-up record | `docs/audits/apex-2026-09-17-followup-fixes.md` | Later claimed corrections. Verified only where a reviewer or the coordinator re-read the cited source. |
| Router and skills | `CLAUDE.md`; `lib/crane/.claude/skills/crane-adversarial-testing/SKILL.md`; `.claude/skills/indexedex-adversarial-testing/SKILL.md` | Deploy, testing, and trust-flag law. |

Reviewer originals and cross-reviews:

- `docs/reviews/apex-2026-09-17-remediation-council/astra-original.md`
- `docs/reviews/apex-2026-09-17-remediation-council/astra-cross.md`
- `docs/reviews/apex-2026-09-17-remediation-council/grok-original.md`
- `docs/reviews/apex-2026-09-17-remediation-council/grok-cross.md`
- `docs/reviews/apex-2026-09-17-remediation-council/minimax-original.md`
- `docs/reviews/apex-2026-09-17-remediation-council/minimax-cross.md`
- `docs/reviews/apex-2026-09-17-remediation-council/kimi-original.md`
- `docs/reviews/apex-2026-09-17-remediation-council/kimi-cross.md`

No forge tests, chain reads, deployments, or broadcasts were run in this round. Recorded test totals in the plan and follow-up record remain unverified claims.

## Astra participation

Astra answered both turns. Neither response was censored.

| Turn | Attempts | Result | Session |
| --- | --- | --- | --- |
| Independent first pass | 1 of 3 | Substantive review | `ses_f25dd7c46ffeidCf68e9sl5AD8` |
| Cross-review | 1 of 3 | Substantive review, same session | `ses_f25dd7c46ffeidCf68e9sl5AD8` |

Other successful sessions, preserved for a follow-up:

| Reviewer | Session |
| --- | --- |
| Grok | `ses_f25dd3165ffeTtprMAGdXAm69C` |
| MiniMax M3 | `ses_f25dce4b0ffeJ52QXMtLXQMGVW` |
| Kimi K3 | `ses_f25dca567ffejJY5p0DtBdSM2K` |

Kimi's first-pass poll timed out. The same Kimi session was resumed and returned a substantive original before any peer text was shared. That is a recovered participant, not a substitute. The cross-review used four substantive originals. This is a four-member round.

Kimi could not read the audit PDF and evaluated audit items through the remediation PRD plus current source. That limit is recorded under unverified items. It does not remove Kimi from the roster.

## Owner follow-up

Already-deployed instances are not in scope. No migration, registry disablement, historical fork replay, or live-instance inventory is required. Fresh deployments of the corrected source are the release unit. Preserved Uniswap V3/V4 trees remain historical source and must not be the bytecode selected for a new deployment.

## Required outcome

The replacement source must be safe to hand to an external auditor without relying on the plan's completion claim. Each confirmed defect below is corrected in production source. Each money or control defect has a production-route test that fails on the current behavior and passes after the correction, except where that item expressly allows comment inspection, source absence, or a documented focused check when a supported route cannot reach the branch. Comment-only defects are closed by editing the cited text and keeping the existing behavioral tests green. This PRD does not authorize implementation in the review session.

Accepted product law that must not be "fixed" away:

- D12 / D28: a later contract caller may consume declared unbooked credit. That is an accepted integrator residual, not a defect.
- D44: the bytecode check accepts EIP-7702 delegated accounts and contract wallets.
- D32: Aave Cross-Version Loop and `BalancerV3PoolStandardExchangeTarget` keep rejecting public pretransfer.
- D6: protocol residual stays booked. It is not paid to `feeTo`.
- Preserved Uniswap V3/V4 trees under `contracts/protocols/dexes/uniswap/{v3,v4}/` stay inventory. They are not the replacement fix.

## Confirmed findings

### RC-01 — Standalone Balancer adapter has no operation-wide reentrancy guard

- **Severity:** Medium
- **File and line:** `contracts/protocols/dexes/balancer/v3/pools/BalancerV3SinglePoolStandardExchange.sol:22`, `69-107`, `131-196`, `218-226`, `228-245`, `262-276`
- **Intended behavior:** D16 includes this adapter. Sibling D16 money routes take a reentrancy lock before external token movement and keep it through reserve settlement. D15 forbids treating booked inventory as caller credit. D12 accepts a later caller of resting credit, not nested use of an operation that has not settled.
- **Broken requirement or invariant:** `exchangeIn` and `exchangeOut` inherit only `IStandardExchange` and have no reentrancy lock. Input is credited, then `_approvePermit2ToRouter` grants maximum token and Permit2 allowances, then the router is called, then reserves are synchronized. Until `_syncReserve`, credit is `balance - _tokenReserve`.
- **Acceptance criteria:**
  - Both money entries reject reentry from funding through approval reset, router return, refund, payout, and reserve sync.
  - An approval opened for an operation is limited to the amount that route will spend. A successful return leaves router and Permit2 allowances at zero. A revert rolls the whole transaction back, including allowances. Do not add `try`/`catch` to clear allowances after a revert. The stale "(M3)" infinite-approve comment at line 262 is updated with this change.
  - A nested entry cannot spend a reserve that the outer operation has already booked.
  - A successful non-reentering route still pulls or credits the intended input, pays the intended output, refunds only the authorized unused exact-output credit, and syncs reserves to post-settlement balances.
  - The control is on this production adapter, not a rewritten harness. A callback-capable token fixture is allowed. Ordinary fixed-behavior tokens remain a negative control that still completes.
- **Non-goals:** Do not enable public pretransfer on D32 surfaces. Do not treat the downstream router lock as a substitute for the adapter lock. Do not claim a demonstrated booked-inventory extraction; the missing guard and stale-book window are the defect. Do not add sender attribution for D12 resting credit.
- **Attribution:** Astra-01, adopted by Kimi as K3-X1. Grok and MiniMax agree the guard gap is real and rate it Medium. Astra retains High for potential accounting impact. Coordinator re-read the cited lines. Lasting value extraction is inference, not an observed execution.

### RC-02 — ERC-4626 local-first payout can deliver more than the accounted amount

- **Severity:** Medium
- **File and line:** `contracts/vaults/standard/erc4626/ERC4626StandardExchangeCommon.sol:80-92`; callers `contracts/vaults/standard/erc4626/ERC4626StandardExchangeOutTarget.sol:108-115` and `contracts/vaults/standard/erc4626/ERC4626StandardExchangeInTarget.sol:144-151`; composing check `contracts/hooks/uniswap/v4/standardExchange/orbital/UniswapV4StandardExchangeOrbitalBufferHookCommon.sol:559-564`
- **Intended behavior:** R14.15 pays the due underlying amount. Exact-output delivery equals the requested amount. Exact-input reporting agrees with what the recipient receives. R6 / D25: an orbital exact-output unwrap does not create a new non-identity buffered-leg face residual.
- **Broken requirement or invariant:** `_payUnderlyingLocalFirst` redeems `previewWithdraw(shortfall)` directly to the recipient and accepts any redemption at least `shortfall`. It does not cap the redemption, retain the difference, or report the larger amount. EIP-4626 `withdraw` sends the requested assets; `redeem` burns the requested shares. Redeeming a rounded-up share requirement does not guarantee delivery of exactly `shortfall`.
- **Acceptance criteria:**
  - The recipient of a local-first underlying payout receives exactly the accounted due amount.
  - Any protocol-vault rounding remainder stays booked on the SE, or the route uses an exact-asset withdrawal whose share charge matches the preview.
  - Exact-input return value equals the amount the recipient received.
  - A non-unit receipt rate and a mixed local-cash plus protocol-vault shortfall are both asserted, including recipient balance delta, returned amount, and ending reserve book.
  - When this SE is the orbital unwrap dependency, a successful capped unwrap leaves no operation-created face above the opening balance on a non-identity buffered leg. Pre-existing D12 resting face is accounted separately and is not paid out by an unrelated pull-funded operation.
- **Non-goals:** Do not send residual to `feeTo`. Do not reintroduce an exact-input refund. Do not treat D12 resting face as a new defect. Do not claim unbounded loss from rounding.
- **Attribution:** Astra-02, agreed by Grok, MiniMax, and Kimi (K3-X2). Coordinator re-read lines 80-92 and 559-564. Orbital face retention is inference from the `>= amountOut` check plus the uncapped redeem; it is part of the acceptance criteria, not a separate exploit claim.

### RC-03 — Stata SE backing omits booked aToken that the shared adapter counts

- **Severity:** Medium
- **File and line:** `contracts/protocols/lending/aave/v3.6/AaveV3StataStandardExchangeCommon.sol:52-58`; `contracts/vaults/standard/erc4626/ReceiptBackedERC4626Target.sol:183-198`; expected-hold registration `contracts/protocols/lending/aave/v3.6/AaveV3StataStandardExchangeDFPkg.sol:245-258`; full-set sync `contracts/vaults/basic/BasicVaultCommon.sol:43-50`
- **Intended behavior:** D45 / R14 require one local-plus-receipt backing calculation for IERC4626, SE, SY, and transition quotes on the same proxy.
- **Broken requirement or invariant:** `_stataBacking` counts held Stata plus booked underlying. `_totalReceiptBacking` also adds booked non-receipt, non-underlying tokens when the Stata marker is set. Package init puts aToken in the expected-hold set when `aToken()` returns one. End-of-route sync books that balance. The two surfaces can then price the same shares against different backing.
- **Acceptance criteria:**
  - Every Stata issuance, redemption, preview, and transition quote uses the same backing function as the shared adapter and includes already-booked aToken at its underlying-equivalent value. D45 / R14 already require that inclusion. Exclusion is not an implementer choice.
  - If aToken is absent from the expected-hold set, the shared helper contributes zero. Do not invent a second aToken balance.
  - A funded control with nonzero booked aToken shows the same share entitlement across the adapter and the SE routes, and a later depositor does not receive shares priced on the smaller basis.
  - Receipt payout limits and existing per-entrypoint fees stay unchanged.
- **Non-goals:** Do not change Aave liquidity-mining reward forwarding to `feeTo` (`AaveV3StataStandardExchangeCommon.sol:182-198`). That stream is not this defect. Do not add a second share ledger. Do not treat an unsolicited aToken transfer as attributable to a depositor.
- **Attribution:** Kimi K3-6. Astra's cross-review agreed and traced booking through the expected-hold set. Grok and MiniMax agree, with practical impact conditional on a nonzero aToken book. Coordinator re-read the four cited sites. Reachability of a nonzero book is inferred from full-set sync, not from an executed deposit.

### RC-04 — Security-critical comments still describe removed refund and pull rules

- **Severity:** Low
- **File and line:**
  - `contracts/vaults/standard/erc4626/ERC4626StandardExchangeOutTarget.sol:17-20`
  - `contracts/vaults/standard/erc4626/ERC4626StandardExchangeCommon.sol:201-211` and `277-281`
  - `contracts/vaults/standard/erc4626/ERC4626StandardExchangeInTarget.sol:126`
  - `contracts/vaults/standard/exchange/protocols/uniswap/README.md:32-38`
  - `contracts/protocols/dexes/balancer/v3/pools/BalancerV3SinglePoolStandardExchange.sol:262` stale infinite-approve comment, corrected with RC-01
- **Intended behavior:** D6 retains dust as book. D15 refunds only pretransferred exact-output `credit - used` and never refunds exact-input overshoot. D17 / D28: false-flag exact-out pulls quoted used; exact-in credits exactly `amountIn` when available is sufficient and does not require the whole surplus to equal the request. R13 requires the integrator text to match that law.
- **Broken requirement or invariant:** The OutTarget header still sends residual dust to `feeTo`. `_securePull` NatSpec still says pull overshoot is refunded immediately. `_burnSeShares` NatSpec still says leftover free shares are refunded to the owner. The InTarget comment repeats the overshoot refund. The FullSpread README still says excess exact-in deliveries revert, V3 pulls a quote buffer, V4 pulls max, and dual exits pull max shares.
- **Acceptance criteria:**
  - Those comments and the README describe the executable rules: no exact-input refund, exact pull-delta equality, exact self-share burn, exact-output refund capped at `credit - used`, dust retained as book, and false-flag exact-out pulling quoted used.
  - A reviewer can check the cited lines against the function bodies without finding the removed behavior described as current.
  - No executable refund, fee, or pull change is made solely to match a stale comment.
- **Non-goals:** Do not revive `_absorbDustToFeeTo`. Do not change FullSpread pull code that already follows D17. Do not edit preserved historical Uniswap source.
- **Attribution:** Astra-03, Grok-2, Grok-3, Kimi K3-1, K3-2, and K3-5. MiniMax agrees. Coordinator re-read the cited comments and README lines. The executable bodies at the ERC-4626 sites do not implement the stale text.

### RC-05 — Unused single-CP HookTarget still implements the pre-remediation exact-out refund

- **Severity:** Low
- **File and line:** `contracts/hooks/uniswap/v4/standardExchange/constantProduct/single/UniswapV4SingleStandardExchangeBufferConstantProductHookTarget.sol:736-754`
- **Intended behavior:** D9 / D15. A pretransfer entry rejects a caller with no bytecode, credits `min(unbooked, maxAmountIn)`, and refunds only `credit - used`. The installed single-CP route already does this on the SE facet.
- **Broken requirement or invariant:** This abstract `exchangeOut` refunds `maxAmountIn - amountIn` on the true flag, with no `LocalCreditLib` budget and no `requirePretransferCaller`. A repository search found no inheritor. The installed cut uses the SE facet helper. The unsafe function remains in the family tree.
- **Acceptance criteria:**
  - The unused function is deleted, or it calls the same guarded pull and refund helper as the installed SE target.
  - Installed selectors and the production diamond cut do not change if the function is not currently exposed.
  - A comment or package cut cannot be the only evidence that the unsafe function is unreachable. The source must not retain a second public money implementation that still refunds `maxAmountIn - amountIn` without the credit cap and caller check. A thin entry that calls the installed guarded helper is allowed.
- **Non-goals:** Do not recut the installed facet. Do not change SeTarget exchange behavior except to share the helper if that is the chosen fix.
- **Attribution:** Grok-1, strengthened by Kimi (no inheritor found) and agreed by Astra and MiniMax. Coordinator search found no `is UniswapV4SingleStandardExchangeBufferConstantProductHookTarget` inheritor. Not on the current cut is not a reason to leave the function in place.

### RC-06 — Orbital capped unwrap reports the approval cap as shares spent

- **Severity:** Low
- **File and line:** `contracts/hooks/uniswap/v4/standardExchange/orbital/UniswapV4StandardExchangeOrbitalBufferHookCommon.sol:550-565`
- **Intended behavior:** D25. The SE pulls the shares it uses. A return value named as shares consumed reports that amount, or the function does not return a share count.
- **Broken requirement or invariant:** After `exchangeOut`, the function assigns `seIn = maxIn`, the approval cap, and discards the SE's reported spend. Current callers do not use the return. The mis-report is still on the security-critical unwrap path.
- **Acceptance criteria:**
  - The returned share count equals the shares the SE pulled, measured by the SE return or by the share-balance delta around the call, or the unused return is removed and every caller is updated.
  - The existing approve-to-cap and approve-back-to-zero sequence remains.
  - A short SE delivery still reverts and rolls back.
- **Non-goals:** Do not change the exact-output SE call into a surplus-creating unwrap. Do not pay the unused share cap to the caller. MiniMax dissents that the assignment is unused and therefore not a functional defect; the requirement is limited to making the return truthful or removing it.
- **Attribution:** Grok-4, agreed by Astra and Kimi. MiniMax dissents on functional impact. Coordinator re-read lines 550-565.

### RC-07 — Shared vault availability math panics on a book deficit and is not the canonical helper

- **Severity:** Low
- **File and line:** `contracts/vaults/basic/BasicVaultCommon.sol:33-36`, `77-103`, `120-135`
- **Intended behavior:** R9. Availability is `balance > booked ? balance - booked : 0`. A deficit authorizes zero new credit and does not fall through to the whole balance. D16 public pretransfer entries reject a caller with no bytecode. The plan preserves historical consumers of the base helper, so a global edit must not silently change them.
- **Broken requirement or invariant:** `_unbookedSurplus` and the base pretransfer branch subtract booked from balance with checked arithmetic, so `balance < booked` reverts instead of returning zero. The base pull does not itself call `requirePretransferCaller`; its NatSpec delegates that check. Checked D16 heirs override the pull. `_refundExcess` remains shared and calls `_unbookedSurplus`.
- **Acceptance criteria:**
  - Every active in-scope D16 refund path that calls `_unbookedSurplus` returns zero credit when balance is below book, and does not pay booked inventory. This is not a live-instance inventory.
  - Either the base pull enforces the contract-caller check when `pretransferred` is true, or a test names each D16 public entry and shows it cannot reach the unguarded base branch.
  - Historical consumers outside the D16 override set are listed before any base-helper edit. Their semantics do not change unless that consumer is itself in D16.
  - The opaque panic is replaced, on D16 paths, by the family's existing insufficient-credit error or by a zero-credit result that the caller then rejects.
- **Non-goals:** Do not mechanically replace every historical caller. Do not treat this as a demonstrated booked-inventory payout. Do not reopen preserved Uniswap V3/V4 delivery accounting.
- **Attribution:** Kimi K3-3. Astra, Grok, and MiniMax agree on the code and rate the production impact Low. Kimi's original severity remains Medium for spec nonconformance and Low for practical impact. Coordinator re-read lines 33-36, 77-103, and 120-135.

### RC-08 — Uniswap V2 pass-through zap-out backing check has no named error

- **Severity:** Low
- **File and line:** `contracts/protocols/dexes/uniswap/v2/UniswapV2StandardExchangeOutTarget.sol:578-580`
- **Intended behavior:** A failed backing check reverts with a named error that identifies the compared quantities. The backing invariant itself stays.
- **Broken requirement or invariant:** The check reverts with an empty `revert()` when pool-token balance is below `vaultLpReserve`.
- **Acceptance criteria:**
  - The same comparison reverts a named error carrying both compared values.
  - The transaction rolls back. Booked LP is not spent.
  - Existing successful zap-out routes still pass.
  - If a supported production route can make pool-token balance fall below `vaultLpReserve` without mocking the vault or writing its storage, that route is the required red/green test.
  - If it cannot, record the attempted preconditions and assert the production check itself reverts the named error. Do not mock the subject, fabricate storage, or hold the named-error edit until a later end-to-end trigger is authorized. Grok, MiniMax, and Kimi read this as existing evidence law. Astra's first requirements pass asked the owner to confirm it. A later targeted Astra session agreed that this fallback is an evidence choice, not an owner decision. That correction does not erase the earlier unanswered cross-review.
- **Non-goals:** Do not weaken the backing comparison. Do not change refund amounts on this route.
- **Attribution:** Kimi K3-4, agreed by Grok, Astra, and MiniMax. Coordinator re-read lines 575-580.

## Audit disposition

These are dispositions of the 2026-09-17 audit against current source. "Refuted in current replacement source" is not a statement that an immutable deployment was upgraded.

| Audit item | Disposition | Notes |
| --- | --- | --- |
| APEX-2026-001-M | Refuted in FullSpread replacement source. Still present in preserved historical source by design. Already-deployed instances are out of scope. | Fresh deployments use the FullSpread packages. Preserved `contracts/protocols/dexes/uniswap/v4/UniswapV4StandardExchangeCommon.sol` is not a new-deploy source. |
| APEX-2026-001-M2 | Out of scope | Instance inventory is not required. Not a separate arithmetic defect. |
| APEX-2026-003 | Refuted in current custody source. Already-deployed custody is out of scope. | `takeShares` burns the requested amount and does not sweep the remainder. Exact-output refund is bounded. D12 resting-share consumption remains accepted. |
| APEX-2026-008 | Original whole-face payout refuted at checked orbital sites. Callback exactness is not closed. | `_refundConservation` pays the operation delta, not opening face. RC-02 remains a separate operation-created surplus concern when the SE over-delivers. |
| APEX-2026-009 | Refuted in current ERC-4626 and Morpho source | Self-share burn is the operation amount. Exact-output refund is `credit - burned`. D12 remains. |
| APEX-2026-004B | Refuted in current ERC-4626 source for the idle-underlying sweep | `_refundOrAbsorbAbove` is absent. Exact-in does not refund idle underlying to the caller. RC-02 is a different payout defect. |
| APEX-2026-005 | Missing-helper claim refuted. Complete consumer conformance not closed. | `LocalCreditLib` exists. RC-07 and the standalone adapter's local availability copy remain. Helper existence is not closure of every payout site. |
| Withdrawn `beforeSwap` guard claim | Refuted. Not an accepted residual. | The Balancer-quad hook still enters through `BeforeInitializeLib`, which checks PoolManager identity. MiniMax's first-pass "accepted residual" label was corrected in cross-review. |
| Weighted-dust High claim | Refuted as High. Unconvertible remainder is the accepted D12 / D36 residual. | Weighted `_refundBufferedDust` does not transfer remaining face to the caller. That residual is not a new defect. |

## Dissent and items that are not requirements

- **MiniMax F-M3-01 is not confirmed.** Astra, Grok, and Kimi dissent. On the cited FullSpread true-flag paths, the refund is the minimum of `credit - used` and measured unused inbound. A later balance increase cannot raise the refund above `credit - used`. MiniMax revised the claim to informational speculation about a non-standard pool. No requirement is opened for it.
- **Grok-5 is not an operative defect.** The shared hook exact-out helper does not itself revert when `used > credit`, but checked callers reject `used > maxAmountIn` before the helper and the helper rejects `used` above unbooked balance. Astra, Grok, and Kimi treat a missing redundant check as informational. Do not add a requirement unless a caller is found that reaches the helper without both bounds.
- **Unused `to` on `_refundPairDust` is not a payout defect.** The body does not transfer to that address. Cosmetic cleanup is optional and is not required by this PRD.
- **Stata incentive rewards forwarded to `feeTo` are not this remediation's dust defect.** Do not change that economics under RC-03 or RC-04.
- **D12 non-atomic contract pretransfer is confirmed as implemented and accepted.** It is not a finding.
- **Severity dissent on RC-01:** Astra High versus Grok, MiniMax, and Kimi Medium. The requirement uses Medium because lasting booked-inventory loss was not shown. The guard fix is still required.
- **Severity dissent on RC-07:** Kimi keeps a Medium spec label. The requirement uses Low because no live D16 payout of booked inventory was shown.
- **Functional dissent on RC-06:** MiniMax says the unused return is not a defect. The requirement is limited to an honest or removed return value.

## Evidence gaps

- No council member executed Foundry. Green-test counts, fuzz counts, and matrix rows in the plan and follow-up record are unverified. The test requirements below name the suites to extend; they do not claim those suites already fail.
- Already-deployed instances and APEX-2026-001-M2 chain inventory are out of scope by the 2026-09-25 owner follow-up. They are not open work.
- Astra's first pass did not body-review every D16 caller. Absence of a finding outside the cited sites is not a pass.
- Kimi did not read the audit PDF. Audit dispositions for Kimi rest on the remediation PRD's restatement plus source.
- Whether a particular configured Balancer pool token can callback into RC-01 was not executed. The missing lock does not depend on that proof.
- Whether a currently deployed Stata proxy has nonzero booked aToken was not read. The source inconsistency in RC-03 does not depend on that read.

## Test coverage

These tests are part of the required outcome. They use the existing production TestBases and package or CREATE3 deploy path. They do not mock the subject. A callback-capable token or a non-unit ERC-4626 stub is a fixture, not a mock of the vault, hook, or adapter. A test that only compiles, or that expects any revert, does not count. The current source is the red baseline. After the correction, the same test is the green proof.

| ID | Extend this suite | What current tests do not prove | Required assertion |
| --- | --- | --- | --- |
| RC-01 | `test/foundry/spec/protocols/dexes/balancer/v3/pools/adversarial/Adversarial_BalancerV3SinglePoolSE.t.sol` | The suite covers skip-pull, bounded refund, and leftover approval after return. It does not reenter during funding, approval, or the router call. | A callback on a configured pool token during `exchangeIn` and `exchangeOut` cannot complete a second money entry. If the outer call reverts, booked reserves and caller balances are unchanged. On success, router and Permit2 allowances are zero and `_tokenReserve` equals the post-settlement balance. A no-callback control still completes with the quoted deltas. |
| RC-02 | `test/foundry/spec/vaults/standard/erc4626/ERC4626StandardExchange_APEX_R14.t.sol`, especially `test_APEX_R14_exits_localFirst_receiptOutNeedsReceipts` | That test checks local-first spending and an approximate receipt delta. It does not assert the recipient's underlying balance equals the accounted due amount when `previewWithdraw` rounds up. | On a non-unit receipt rate, exact-in and exact-out local-first exits pay the recipient exactly the accounted amount. The returned exact-in amount equals that delta. If the chosen method creates a redemption remainder, it stays booked and is not paid to the recipient or to `feeTo`. An exact-asset withdrawal is not required to create a remainder. Add the same recipient-delta assertion to one orbital capped-unwrap route that uses this SE, so a successful swap does not leave operation-created face above the opening balance. |
| RC-03 | `test/foundry/spec/vaults/standard/erc4626/ReceiptBackedERC4626_SharedFacet.t.sol` and `test/foundry/spec/protocol/lending/aave/v3.6/AaveV3StataStandardExchange_APEX_R14.t.sol` | The shared-facet suite checks marker dispatch and that the Stata proxy has an aToken hold slot. It does not fund a nonzero booked aToken and compare adapter entitlement with SE entitlement. | On one production Stata proxy, nonzero booked aToken is included by both the adapter and the SE preview and exchange paths. A later deposit is priced on that same basis. Generic ERC-4626 mode still has no aToken term. |
| RC-04 | No new money test | Existing ERC-4626 and FullSpread route tests already forbid exact-in refunds and dust-to-fee payouts. They do not fail when a comment is stale. | Edit the cited comments and README. Re-run the existing ERC-4626 R14 suite and one FullSpread exact-out suite. Record that the cited lines no longer describe pull-max, overshoot refund, leftover-share refund, or dust-to-fee. |
| RC-05 | `test/foundry/spec/hooks/uniswap/v4/standardExchange/constantProduct/single/UniswapV4SingleStandardExchangeBufferConstantProductHook_Surface.t.sol` | The surface suite proves the installed cut. It does not fail while the unused abstract `exchangeOut` still refunds `maxAmountIn - amountIn`. | Delete that function or route it through the installed guarded helper. The surface suite still passes, and a source search shows no second public `exchangeOut` with the unguarded refund. Installed selectors do not change if the function was not on the cut. |
| RC-06 | Existing orbital unwrap or surface suite under `test/foundry/spec/hooks/uniswap/v4/standardExchange/orbital/` | Callers ignore the return, so current tests cannot see that `seIn` is assigned the approval cap. | If the return remains, a production-hook test asserts it equals the share-balance delta around the SE call. If the return is removed, the same unwrap test still pays the quoted token amount and clears the SE allowance. |
| RC-07 | Existing Uni V2, Camelot, and Aerodrome secure-pull suites, plus a direct helper test only if no production route can create `balance < book` | Current route tests do not show the panic-versus-zero-credit behavior. | A D16 refund or credit path with balance below book authorizes zero new credit and does not pay booked inventory. It reverts the family's insufficient-credit error when the caller requests more than zero. It does not revert with an arithmetic-underflow panic. Name the D16 overrides that already guard the base pull, and show a no-bytecode caller is still rejected on those public entries. |
| RC-08 | `test/foundry/spec/protocol/dexes/uniswap/v2/UniswapV2StandardExchange_SecRemediation.t.sol` | A successful zap-out does not prove the backing failure is named. | If a supported route can reach the check, that route must fail before the fix and pass the named error after it, with unchanged LP reserve and a funded success control. If it cannot be reached without mocking or storage writes, document that attempt and assert the production check. Do not invent a completion gate beyond that. |

Shared test rules:

- Red then green uses the same assertion. Do not loosen an expected amount, skip the case, or replace the production proxy with a rewritten helper.
- Exact-output and exact-input controls from the same prepared state remain beside every rejection.
- Do not add a test whose only oracle is a passing return value. Assert balances, reserves, allowances, and the named error.
- Hermetic profile only. No `via_ir`, no live RPC, and no fork of an already-deployed instance.

## Requirements follow-up

This is a requirements clarification, not a new defect round. Sessions: Astra `ses_f25dd7c46ffeidCf68e9sl5AD8`, Grok `ses_f25dd3165ffeTtprMAGdXAm69C`, MiniMax `ses_f25dce4b0ffeJ52QXMtLXQMGVW`, Kimi `ses_f25dca567ffejJY5p0DtBdSM2K`.

All four requirements first passes found no new economic ruling. Grok, MiniMax, and Kimi completed cross-review and still found no human question. Astra's cross-review resume returned no review text. The first rewritten retry was aborted before a result. A later human-requested Astra session, `ses_f242ff120ffeJtOYk5QvnC0chn`, returned a substantive agreement: no human question remains, including on the RC-08 evidence fallback. That is a targeted Astra response, not a new four-member round. The empty cross-review was not resumed.

No question blocks implementation. The closed readings are: include booked aToken; a revert rolls back rather than catching; delete or align the unused hook function; make or remove the unused orbital return; name the Uniswap V2 backing error. RC-05, RC-06, and the error name are implementer choices.

The final clarity pass found no new product-law question. Grok treated two acceptance sentences as handoff blockers; Astra, MiniMax, and Kimi treated them as wording. Both sentences are now aligned: an exact-asset withdrawal need not create a remainder, and a guarded shared helper is not a banned second implementation. Kimi's include-or-exclude finding was stale against the current RC-03 text.

## Coordinator notes

These notes are coordinator notes, not an additional reviewer's findings. The coordinator re-read the production lines cited in RC-01 through RC-08 before confirming them. Consensus and the plan's completion statement were not treated as proof. No code, tests, config, or scripts were edited.
