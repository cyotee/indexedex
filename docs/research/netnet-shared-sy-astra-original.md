# Astra — shared-SY independent original

Research only. Read current **v0.21 PRD, all 1,067 lines**, CLAUDE, relevant canonical Crane/local skills and current reserve/family law. No peer artifacts, shell, tests, delegation, implementation or config changes. Only this report written. No independently exposed runtime model/provider metadata; Astra is the assigned label. Access date: 2026-09-27, supplied environment date.

**P** = `docs/strategies/ohm-style/netnet-pendle/NETNET_PENDLE_DETF_PRD.md`. The present user instructions supersede conflicting v0.21 text. Source line citations are unpinned local snapshots.

## 1. Finding: selected asymmetric pricing/funding is implementable intent, not a standard-swap proof

C09 and C10 are answered: NET/sNET inputs use Keep-YT; unbalanced HLP uses existing Balancer V3 Weighted liquidity math. Raw DETF input stays held; output comes from held DETF. Ordinary NET output and sNET output spend **one shared eligible SY inventory**, held-first, then claim if insufficient, then redeem. NET retains PLP/YT-derived pricing without liquidating that position for ordinary output.

Preserve these choices. Neither a conventional two-reserve swap update nor Pendle zap parity proves the resulting cross-book accounting. That is the principal engineering gate, not a reason to reject the design or ask the owner again.

## 2. BasicVaultRepo: actual API and integration risks

**Observed:** `contracts/vaults/basic/BasicVaultRepo.sol:20–28,83–109` stores token membership and a **locally held reserve snapshot**. `_updateReserve(IERC20,uint256)` assigns an absolute supplied amount; it does not transfer, query balances, accrue claims, subtract automatically or validate eligibility. `_initialize`/`_addVaultToken` manage membership (`:51–80`). Never put pending interest, NET-rated SY value or PLP/YT virtual value into this held-token mapping.

`MultiAssetBasicVaultRepo.sol:21–27,82–95` uses the **same storage slot and equivalent field layout**. These are not independent books. Existing integrations use that name: `BasicVaultCommon.sol:28–53` reads snapshots and synchronizes to actual balances; `:80–105` credits pretransfers using balance minus booked reserve. The Weighted hook target at `contracts/hooks/uniswap/v4/standardExchange/weighted/UniswapV4StandardExchangeWeightedBufferHookTarget.sol:455–495` similarly synchronizes and checks unbooked balances.

**Inference:** an unsolicited Pendle force-claim can appear as unbooked SY and be miscredited as a user's HLP pretransfer if imported helpers are used unchanged. Updating the snapshot only after a swap is insufficient. Reconcile known protocol receipts before contribution credit, distinguish the call's actual deposit, and synchronize every affected held-token boundary under one callback-safe transition. Do not invent a new Repo API.

Maintain separate provenance/eligibility/payable accounting alongside the shared held snapshot. `balanceOf` or the snapshot alone is not “spendable interest.” Pending claims live outside BasicVaultRepo; principal-exit SY, fee payables and unclassified balances must not become ordinary swap capital merely by synchronization.

## 3. Shared-SY conservation and real blockers

For eligible held SY E, net claimable SY R, and actual SY consumed d, claiming net c should transition `(E,R) -> (E+c,R-c)` for already-accounted accrual; redemption then reduces E by d. New accrual and native fees require explicit reconciliation. This is an accounting reference, not a mandated storage layout.

Observed Pendle `lib/crane/contracts/protocols/perps/pendle/core/YieldContracts/InterestManagerYT.sol:43–57,63–79` checkpoints accrual, deducts interest fees, zeros the accrued claim and transfers net SY. `PendleYieldToken.sol:166–193` permits claiming for a supplied user and sends rewards/interest to that user. Thus last-call return values alone miss previously force-claimed assets.

Required transition specification:

- NET/sNET input increases acquired PLP/YT and its internal sub-reserve accounting; do not also credit the input's transient SY as held interest or apply a second nominal sNET-reserve credit.
- Ordinary NET/sNET output decreases the **same** SY cash/claim book. It does not debit PLP/YT merely because NET price used that position. Every subsequent quote, HLP admission/exit, fee invariant and TWAP observes all affected books.
- NET↔sNET cross-swaps can increase the position leg while decreasing SY even though a conventional pair model would mutate different coordinates. Recompute projected/post-state from actual transformations; do not persist invented balances to force constant-invariant behavior.
- Received DETF increases raw inventory without supply changes; sold DETF reduces held inventory. User swaps do not automatically mint HLP or create DETF-owned HLP.

**Liquidity gate:** a large PLP/YT valuation can quote more NET than shared SY can redeem. Enforce actual shared availability and the retained non-drainage/user-limit requirements; insufficient realization reverts atomically, without PLP/YT fallback. Exact-output inverses, truthful `max*` and callback-visible intermediate states need explicit specification. NET and sNET cannot each reserve the same SY independently.

Failed fee forwarding retains its token/payable and continues. Failure of a required upstream claim or SY redemption is different: non-blocking forwarding does not authorize swallowing funding failure or paying from principal. Test force claims, duplicate claims, recipient rotation, fee-token/SY collisions and interleaved HLP exits. Positive SY outflow to users remains an economic cost even when Pendle principal grows.

## 4. Balancer unbalanced reference: resolved policy, concrete compatibility discrepancy

Context7 was consulted first. Vendored `lib/crane/contracts/external/balancer/v3/vault/contracts/BasePoolMath.sol:126–205` prices unbalanced additions by invariant growth after fees on nonproportional amounts, with directed rounding and invariant bounds. Single-token exact-output withdrawal (`:277–339` and following return) computes taxable imbalance, fee-adjusted invariant loss and rounded-up BPT debit. This is not h/H on selected legs and leaves no retained omitted-leg coupon. Four custody units must feed this model coherently; nested PLP/YT realization follows after its allocated subshare debit.

**Important observed mismatch:** the selected local wrapper `UniswapV4StandardExchangeWeightedBufferHookMath.sol:472–498` calls its single-exact-output exit fee treatment **approximate**, grossing up the whole output. Balancer computes the taxable portion from the invariant. Wrapper join `:323–330` also subtracts one only for positive additions, whereas BasePoolMath `:152–154` subtracts one across the array under its scaling contract. Do not declare exact reference parity from names/comments. Pin the complete scaling/caller context and reconcile these differences under the latest existing-Balancer requirement. This is source compatibility work, not renewed C10 economics.

## 5. Full reconciliation map

Replace—not merely override—the following P text:

- **C09 stale:** 20,91,146,161,180,200,230,310,320,324,326,348,476,479,576,683,811,837,850 and historical/current summaries 981,1061,1065. Record NET/sNET Keep-YT and restore truthful route descriptions.
- **C10 stale:** 101,171,175,291,311,318,393,809,811,815,838,865,886,1061,1065. State invariant-priced Weighted unbalanced processing; retain h/H only for full proportional mode and joint proportional PLP/YT allocation inside its leg.
- **Wrong NET funding:** 51,91,103,192,349,351,353,367,403,424,809,811,814,839,874,894,1043 and any v0.21 summary implying ordinary NET position liquidation. Keep §7.1.2 arithmetic as NET valuation/HLP-position exit math; remove its use as ordinary NET funding/debit.
- Add explicit held-first→claim/reconcile→redeem shared-SY flow, BasicVaultRepo API/storage obligations, NET/sNET shared non-drainage, raw DETF held-in/held-out semantics and whole-book transition acceptance. Update A01/A02/A03/A05/A12/A18/A27/A33/A39/A46–48 accordingly.

Keep direct SE-share HLP payouts without SE redemption, direct SY HLP payouts, allocated position exits, owned-HLP contraction boundaries, all latest TWAP/linear-expansion/fee-share/retry policies and minimal-input atomic rollover. Do not silently extend ordinary-swap funding rules into a redesign of separately specified contraction/reinvestment.

## 6. Readiness and evidence

No additional confirmation of C09/C10 or asymmetric funding is needed. Remaining blockers are concrete transition math, finite SY deliverability, inherited-pretransfer safety, reference-math compatibility, validated SY conversion/provider, subshare lifecycle, and existing external-note liveness. Only a demonstrated incompatibility or genuinely unclassified spendability/economic parameter requires escalation.

Primary source fetched after Context7 `/llmstxt/balancer_fi_llms-full_txt`, accessed 2026-09-27: https://raw.githubusercontent.com/balancer/balancer-v3-monorepo/main/pkg/vault/contracts/BasePoolMath.sol . Upstream/vendored BasePoolMath is Solidity `^0.8.24`; local BasicVault/Weighted wrapper `^0.8.0`. No release/hash or deployment was verified. No proprietary source sent externally. High confidence on Repo semantics and stale text; no executed conservation, gas, profitability or security proof. No council consensus claim. Stop after original.
