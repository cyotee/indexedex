# Astra — shared-SY bounded cross-review

Read all three complete other originals together; no cross-review artifacts read. Originals remain unchanged. Research only: no delegation, shell, tests, code/config edits or deployment. This report is the sole write; apply_patch was available and used. No independent runtime/provider attestation was exposed.

P = `docs/strategies/ohm-style/netnet-pendle/NETNET_PENDLE_DETF_PRD.md` v0.21; G/M/K = `docs/research/netnet-shared-sy-{grok,minimax,kimi}-original.md`. Sources below were directly rechecked; unpinned snapshots, not deployed proof.

## Agreement and corrections

All originals accept C09/C10 closure and the intentional separation of NET pricing from shared-SY funding. Preserve that direction, existing HLP units, TWAP/expansion/fee-share policies and atomic/minimum-output requirements. Agreement proves neither economic safety nor quote parity.

**1. Locally held PLP/YT are valid held-token snapshots.** M:40,59,72 incorrectly excludes them as positions “held ... at the Pendle market.” `contracts/vaults/basic/BasicVaultRepo.sol:25,92` explicitly permits locally held **LP token balances**, while excluding the underlying deployed reserves those tokens represent. Hook-held PLP and YT ERC20 quantities may therefore be booked. Internal subshares, claimable SY and underlying PT/SY exposure require separate accounting. Grok's similar “not PLP inside Pendle” shorthand (G:38) needs this distinction.

**2. Raw snapshot is not economic eligibility.** `_updateReserve(IERC20,uint256)` assigns an absolute value (`BasicVaultRepo.sol:98–109`); it neither measures nor classifies assets. G:40's raw reserve plus claimable equation is valid only after excluding noneligible/segregated quantities from the economic view. K:17 correctly separates provenance and payables. M:42 must not aggregate held **and claimable** through this Repo: claimable is not locally held. Tracking excluded cash for pretransfer protection does not make it backing.

**3. Twin Repos share storage.** `BasicVaultRepo.sol:20–27` and `MultiAssetBasicVaultRepo.sol:21–26` have the same slot and equivalent layout. K:18 corroborates Astra. They are not two independent reserve ledgers; preserve the owner's BasicVaultRepo requirement and account for existing twin-name consumers. A common slot does not by itself prove every integration uses compatible token units.

**4. Force-claim pretransfer theft needs an explicit negative case.** `BasicVaultCommon.sol:85–105` credits pretransfer claims against `balanceOf − booked`. If book=100, a protocol force-claim adds 10, and an authorized contract caller contributes nothing but claims 10, that helper can credit the protocol receipt unless reconciled first. This is a conditional vulnerability in naïve reuse, not an executed exploit against a custom implementation. End-of-operation synchronization, as proposed by G/K, does not alone prevent it. Reconciliation must precede contribution attribution without swallowing legitimate same-call deposits.

**5. Existing wrapper is not demonstrated exact Balancer parity.** M:22's “Verified…Do not re-derive” establishes selectors/helpers, not arithmetic equivalence. The local `contracts/hooks/uniswap/v4/standardExchange/weighted/UniswapV4StandardExchangeWeightedBufferHookMath.sol:472–498` explicitly approximates single-exact-output fees by grossing up the entire output. Actual vendored `lib/crane/contracts/external/balancer/v3/vault/contracts/BasePoolMath.sol:277–342` computes taxable imbalance from the invariant and rounds BPT debit upward. Retain Astra's compatibility gate; trace scaling/callers and use the owner-selected existing Balancer semantics rather than silently accepting the approximation. C10 remains answered. K:22's generic “single-token exact-out uses computeBalance” applies to the add direction; exact-token-out removal above uses invariant calculations.

**6. Whole-snapshot recomputation does not mean every coordinate changes.** K:38 says NET-out changes both rated books. Qualify: holding external state and the incoming leg fixed, the **output debit alone** reduces SY but need not alter PLP/YT-derived NET valuation. G:59 correctly identifies that distinction, but “NET virtual unchanged” is not universal: Keep-YT input, time/index changes, or other transitions can alter it. Recompute the complete projected snapshot; never impose a fictitious NET-reserve decrement just because NET was paid.

**7. Preserve principal-exit rights and USDG's actual funding.** G:53's “shrinks only” list omits separately authorized owned-reserve contraction/reinvestment. M:55 proposes replacing P:462's burn-funding paragraph with ordinary-swap rules; reject that scope change. M:66 incorrectly generalizes shared-SY delivery to USDG: USDG still redeems SE inventory. M:86's subshare rounding on shared-SY output is unnecessary absent another operation affecting subshares. Preview functions do not redeem tokens; replace M's “redeemed via SY preview” with actual redemption plus preview verification.

## Exact reconciliation recommendation

Replace P:20,146,180,310,348,476,479,576,837 and corresponding summaries/tests with resolved NET/sNET Keep-YT input. Replace P:101,171,175,291,393,838 with existing Weighted invariant-priced unbalanced semantics—no h/H selected-leg shortcut or omitted-claim retention.

Replace P:51,91,103,192,349,351,353,367,403,424,814,839,874,894 and dependent summaries with:

> Ordinary NET and sNET outputs debit one eligible SY pool. Use held eligible SY first; if insufficient, collect pending interest/rewards, reconcile receipts once, retain SY and attempt other-token forwarding under the retry policy, then redeem sufficient SY to the requested token. NET pricing remains the joint PLP/YT valuation. Ordinary output does not liquidate or debit PLP/YT. Insufficient delivery reverts the transaction without principal fallback.

Keep P:379–391 HLP principal allocations, §7.1.2 allocated-position realization and P:434,440–466 owned-reserve burn/reinvestment rights. Add BasicVaultRepo local-snapshot requirements separately from eligibility and claims. Retain my original full stale-text inventory for moderator reconciliation.

## Acceptance and genuine open work

Require tests for force-claim-before-pretransfer; held-sufficient/no-claim and held-insufficient/claim paths; NET then sNET shared-budget depletion; failed payout rollback; non-blocking forwarding with retained liabilities; direct/retained/principal SY provenance; USDG SE delivery; HLP/owned-reserve principal exits; no phantom subshare debit; and source-level Balancer differential cases including exact-output fees and rounding.

No fresh owner confirmation is required for C09/C10 or asymmetric funding. Engineers must specify C11 lifecycle, C12 eligible-SY classification and finite-output inversion. Seek a decision only for a concrete unclassified contribution/incentive spendability case, unset economic parameter or demonstrated incompatibility—not generic permission to proceed. High confidence on source corrections; no live-chain, tests or economic proof. Stop after this single cross-review.
