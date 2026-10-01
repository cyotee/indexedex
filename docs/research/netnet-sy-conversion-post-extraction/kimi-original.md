# Kimi K3 — original first pass: PendleStakedNetSY conversion semantics and Weighted-quote/SY-funding integration

| Field | Value |
| --- | --- |
| Researcher | Kimi K3 (`kimi-code-plan-global/k3`, variant high), independent original pass |
| Date / access date | 2026-09-28 |
| Status | Research only. No shell/tests/deployments/product edits/delegation. No peer findings read. NEW_COUNCIL_RESTART_HANDOFF §6 not read. |
| Question | For the actual `PendleStakedNetSY` compilation: exact supported deposit/redemption branches, integer conversion/inverse formulas, epoch/index ordering, receipt/minimum-output semantics funding selected NET/sNET routes; and how to integrate existing Weighted quotes with eligible held/net-claimable SY without confusing pricing coordinates and funding. |
| Primary evidence | `docs/research/netnet-sy-conversion-2026-09-27/VERIFIED_SY_SOURCE_EXTRACTS.md` (25 decoded sources; manifest reports JSON round-trip + target keccak256 match, **not** fresh runtime proof). Local NetNet reference bodies under `lib/crane/contracts/protocols/pol/net/src/` (reference, **not** verified deployed equivalence). |
| Governing docs | PRD v0.33; Implementation/Test Plan v0.7 (esp. §6.4, §6.5); PRD_OPEN_QUESTIONS.md (NN-07, NN-10). |

Line numbers cited as `EXTRACT:<n>` refer to `VERIFIED_SY_SOURCE_EXTRACTS.md`; `StakedNET.sol:<n>`, `Staking.sol:<n>`, `NET.sol:<n>`, `Constants.sol:<n>` refer to the local Crane NetNet reference; `Quote:<n>` refers to `lib/crane/contracts/protocols/dexes/balancer/v3/utils/BalancerV3WeightedPoolQuote.sol`.

## 0. Source identity and trust tier (observed fact)

- Chain 4663 candidate SY proxy `0x5d446a2be952f4f9ba241b382a73ad3b1819aaf5`; service-resolved implementation `0xAdAb46E7024d34E18BeBB058D374aa1069DB461E`; Sourcify match 47105638, creation/runtime `exact_match`, verified 2026-09-04T08:05:04Z; compilation target `PendleStakedNetSY` (plan §6.5; extract manifest lines 11–21).
- External build: solc 0.8.30+commit.73712a01, optimizer 1,000,000 runs, Cancun, `viaIR=true` — **not** local compiler authorization (plan §6.5 table).
- The extract is a decode of an already-downloaded public Sourcify response. Round-trip/hash agreement proves the decode matches the payload; it does not prove current on-chain bytecode, current proxy storage, or deployed-configuration values. L3 and G1 remain open evidence items; this report does **not** claim their closure.
- The decimals-wrapper **implementation** is absent from the compilation (only `IPDecimalsWrapperFactory.sol` interface, EXTRACT:389–402). `yieldToken` = `getOrCreate(sNet, 18)` and `scaledNet` = `getOrCreate(net, 18)` (EXTRACT:58–67). SY decimals are therefore 18 via `PendleERC20Upg(IERC20Metadata(_yieldToken).decimals())` (EXTRACT:211–214, 692). Wrapper behavior (mint/burn/transfer semantics, dust receiver) is **not readable from this compilation**; per the operator's instruction this absence must not block unused routes, and no behavior is inferred for it here.

## 1. Unit and decimal boundaries (observed fact)

| Quantity | Decimals / scale | Evidence |
| --- | --- | --- |
| NET | 9 (`NET_UNIT = 1e9`) | `Constants.sol:13–14`; `NET.sol:35` |
| sNET | 9 | `StakedNET.sol:21` |
| sNET `index()` | 9 (starts at 1e9) | `StakedNET.sol:45–50,68–70` |
| SY shares | 18 (from 18-decimal wrapper of sNET) | EXTRACT:58–67, 211–214 |
| `scaledNet` (asset) | 18 | EXTRACT:66, 163–165 |
| `DECIMALS_OFFSET * INDEX_BASE` | 1e9 × 1e9 = 1e18 | EXTRACT:44–45 |
| `exchangeRate()` | 18 (syncedIndex × 1e9), denominated in scaledNet | EXTRACT:108–111, 163–165 |

`assetInfo()` returns `(TOKEN, scaledNet, 18)` (EXTRACT:163–165): the SY's accounting asset is the 18-decimal NET wrapper. `pricingInfo()` returns `(sNet, false)` (EXTRACT:167–169): reference token sNET, **not** strictly equal — i.e. the SY itself declares that 1 SY ≠ 1 sNET. This directly confirms plan §6.5 fixed-contract point 2: `SY shares = native sNET × 1e9` is false in general; the conversion runs through the 9-decimal dividend index.

## 2. Supported branch table (observed fact, from the decoded target)

`getTokensIn()` = `getTokensOut()` = `[net, sNet]`; `isValidTokenIn/Out` accept exactly those two (EXTRACT:147–161). No PT/YT/USDG/native-ETH branch exists in this SY.

| # | Branch | Forward integer formula (exact floors) | State-changing steps inside SY | Index used |
| --- | --- | --- | --- | --- |
| D1 | `deposit(tokenIn = net, a)` | `shares = floor(a × 1e18 / index_after_stake)` | `_transferIn(net, msg.sender, a)` pulls NET from caller (EXTRACT:240, TokenHelper EXTRACT:1414–1417); `staking.stake(address(this), a)` (EXTRACT:84–86) — staking re-pulls NET from the SY (approved `type(uint256).max` at init, EXTRACT:72) and sends `a` sNET **to the SY** | `IStakedNet(sNet).index()` read **after** the stake call (EXTRACT:87) |
| D2 | `deposit(tokenIn = sNet, a)` | `shares = floor(a × 1e18 / index_current)` | `_transferIn(sNet, msg.sender, a)` pulls sNET into the SY; no staking call (EXTRACT:84–88: `if (tokenIn == net)` only) | current (possibly stale) `index()` |
| R1 | `redeem(tokenOut = net, s)` | `out = floor(s × syncedIndex / 1e18)` | burn `s` shares (see §4), then `staking.unstake(receiver, out)` (EXTRACT:95–97): staking pulls `out` sNET from the SY (approved at init, EXTRACT:73) and transfers `out` NET to `receiver` | `_syncedIndex()` — projected one-epoch index (EXTRACT:96) |
| R2 | `redeem(tokenOut = sNet, s)` | `out = floor(s × index_current / 1e18)` | burn `s` shares, then `_transferOut(sNet, receiver, out)` — direct sNET transfer from SY custody (EXTRACT:98–100; TokenHelper EXTRACT:1423–1431) | current (possibly stale) `index()` (EXTRACT:99) |
| P1 | `previewDeposit(net, a)` | `floor(a × 1e18 / syncedIndex)` | none | projected (EXTRACT:135) |
| P2 | `previewDeposit(sNet, a)` | `floor(a × 1e18 / index_current)` | none | current (EXTRACT:135) |
| P3 | `previewRedeem(net, s)` | `floor(s × syncedIndex / 1e18)` | none | projected (EXTRACT:143) |
| P4 | `previewRedeem(sNet, s)` | `floor(s × index_current / 1e18)` | none | current (EXTRACT:143) |
| E1 | `exchangeRate()` | `syncedIndex × 1e9` (18-dec, scaledNet terms) | none | projected (EXTRACT:108–111) |

Base-level guards (SYBaseUpgV2, observed): zero deposit reverts `SYZeroDeposit` (EXTRACT:238); zero redeem reverts `SYZeroRedeem` (EXTRACT:260); invalid token reverts (EXTRACT:237, 259); `amountSharesOut < minSharesOut` reverts `SYInsufficientSharesOut` (EXTRACT:243); `amountTokenOut < minTokenOut` reverts `SYInsufficientTokenOut` (EXTRACT:269); `deposit` is `payable nonReentrant`, `redeem` is `nonReentrant` (EXTRACT:236, 258); pause blocks mint/burn/transfer via `_beforeTokenTransfer … whenNotPaused` (EXTRACT:363); owner-only `pause/unpause` (EXTRACT:355–361); supply cap checked only on mint, initialized to `type(uint256).max` (EXTRACT:71, 175–184, 439–444). `_totalSupply` is `uint248` (EXTRACT:687).

**Empty reward surface (observed):** `claimRewards`, `getRewardTokens`, `accruedRewards`, `rewardIndexesCurrent/Stored` all return empty arrays (EXTRACT:309–333). Therefore the PRD's "net-claimable SY interest" cannot come from the SY's own reward interface; it comes from Pendle market/YT interest claims (`userInterest` of the hook address, PRD §7.1.3) paid **in SY**. This is a branch-specific dependency distinction the plan should state explicitly.

## 3. Current vs projected index — exact floors, cap, zero-circulating (observed SY; local reference for the mirrored logic)

`_syncedIndex()` (EXTRACT:113–125):

```text
(length, number, epochEnd, queuedProfit) = staking.epoch()
currentIndex = sNet.index()                              // = floor(_indexGons / gonsPerFragment)
if block.timestamp < epochEnd or queuedProfit == 0: return currentIndex
supply      = sNet.totalSupply()
circulating = supply − sNet.balanceOf(staking)
if circulating == 0: return currentIndex
newSupply = supply + floor(queuedProfit × supply / circulating)
if newSupply > MAX_SNET_SUPPLY (type(uint128).max): newSupply = MAX_SNET_SUPPLY
return floor( INDEX_GONS / floor(TOTAL_GONS / newSupply) )
```

Local-reference mirror check (inference, not deployed equivalence):

- `StakedNET.rebase` (`StakedNET.sol:83–100`): `rebaseAmount = floor(profit × totalSupply / circulating)`; `newSupply` capped at `MAX_SUPPLY = type(uint128).max`; `gonsPerFragment = floor(TOTAL_GONS / newSupply)`; `index = floor(_indexGons / gonsPerFragment)` (`:68–70,96–98`). The SY's projection reproduces the **same two-floor structure**: inner `floor(TOTAL_GONS/newSupply)`, outer `floor(INDEX_GONS/inner)` — provided `INDEX_GONS == _indexGons`, which holds iff `Constants.NET_UNIT (1e9) == INDEX_BASE (1e9)` and both contracts share `INITIAL_FRAGMENTS = 5_000_000_000e9` and `TOTAL_GONS = max − (max % INITIAL_FRAGMENTS)` (EXTRACT:47–51 vs `StakedNET.sol:25–28`; `StakedNET.sol:48`; `Constants.sol:14`). Constants match in the local reference. **Deployed equivalence of these constants and of the rebase formula is G1 evidence, not established by this decode.**
- Zero-circulating branch matches: local staking only calls `sNet.rebase` when `circulating > 0` (`Staking.sol:138–144`); SY returns current index in that case (EXTRACT:120).
- The cap branch matters: at the cap, the realized index is a pure function of `MAX_SNET_SUPPLY`, so the projection remains exact; below the cap it is exact iff the mirror holds.

**Asymmetry (observed fact, economically material):** R1/P3/E1 use the projected index; D2/R2/P2/P4 use the current (stale) index. When exactly one epoch is overdue with queued profit, redeeming to sNET pays the pre-rebase rate while redeeming to NET pays the post-rebase rate. The difference accrues to remaining SY holders (the SY's sNET custody rebases later). This is inherent to the compilation, not a bug to "fix"; route semantics must choose branches deliberately (§6).

## 4. Epoch/index ordering and overdue-epoch advancement (observed local reference; mirrored SY reads)

Local `Staking` ordering:

- `stake(to, amount)`: `_rebaseIfDue()` **first**, then `net.transferFrom(msg.sender → staking)`, then sends `amount` sNET 1:1 (`Staking.sol:88–104, 158–160`). For the SY, `msg.sender` is the SY and `to = address(this)`, so the SY ends up holding the sNET.
- `unstake(to, amount)`: `_rebaseIfDue()` first, then `sNet.transferFrom(msg.sender → staking, amount)`, then `net.transfer(to, amount)` (`Staking.sol:119–126`).
- `_rebaseIfDue()` advances **exactly one epoch per call**: if `block.timestamp >= end`, optionally distribute queued profit via one `sNet.rebase`, then `end += length; number += 1; oracle.checkpoint(); distribute += distributor.distribute()` (`Staking.sol:134–151`). Multiple overdue epochs require multiple calls ("back-to-back calls catch up", `Staking.sol:16–17`). This matches plan §6.5 point 4 and the SY's single-epoch projection: `_syncedIndex` projects **one** epoch only (EXTRACT:113–125), which is exactly what one `stake`/`unstake` call realizes. Consequently P1/P3 remain execution-parity previews for the immediately following call **no matter how many epochs are overdue** (the call advances one, the preview projects one) — provided the mirror constants/formula hold and no intervening transaction changes state.
- sNET-direct branches (D2/R2) do not touch staking, so they never advance the epoch; a permissionless `staking.rebase()` (`Staking.sol:129–132`) settles one overdue epoch if a route wants current == synced before using sNET branches.
- Warmup hazard (inference from local reference): with `warmupEpochs > 0`, `stake` accrues gons into `warmup[to]` and does **not** deliver sNET (`Staking.sol:92–101`), and `to != msg.sender` reverts `ThirdPartyWarmup` (`:97`). The SY calls `stake(address(this), …)` so the third-party check passes, but a nonzero warmup would strand deposited value in the SY's warmup entry while shares are minted immediately. Local default is `STAKING_WARMUP_EPOCHS = 0` (`Constants.sol:29`). **The deployed staking's warmup value is unverified G1 configuration; the SY integration is only sound at warmup = 0 (or with a claim-aware wrapper, which this SY does not implement).**

## 5. Custody, pulls, transfers, minOut and receipt measurement (observed fact)

- Caller/shares custody: `redeem` burns from `msg.sender` when `burnFromInternalBalance = false`, or from the **SY contract's own** share balance when `true` (EXTRACT:262–266). Hook-held SY shares are ordinary ERC-20 balances of the hook proxy; the hook route therefore uses `false` with the hook as `msg.sender` to the SY proxy. `true` is only meaningful for shares previously deposited into the SY itself (e.g. router/market internal balances) — confirming plan §6.5 point 5.
- Token custody: the SY's backing is sNET fragments held either at the SY (D2 deposits) or notionally via the staking inventory — in both cases the SY is the sNET holder of record (`stake(address(this),…)`, EXTRACT:85). Redemptions are funded from that sNET: R1 via staking's `transferFrom` from the SY, R2 via direct transfer.
- Burn-before-compute ordering (EXTRACT:262–268): shares are burned before `_redeem` computes `out`. Numerically harmless here (conversion does not read SY supply), but it means a downstream revert (e.g. insufficient SY sNET balance in `unstake`'s `transferFrom`) rolls back the burn — funding failure is atomic, consistent with plan §6.4's full-rollback rule.
- minOut semantics: `minSharesOut`/`minTokenOut` compare **nominal computed** amounts, not measured receiver deltas (EXTRACT:243, 269). The SY measures nothing. Two consequences (observed + inference):
  - D1 does not measure the actual NET received from the caller pull. If the caller→SY NET transfer were taxed (NET is conditionally FoT: 500 bps when `taxEnabled && !isTaxExempt[from] && !isTaxExempt[to] && (isTaxedPair[from] || isTaxedPair[to])`, `NET.sol:131–145`), the SY would receive `a − tax` and the subsequent `staking.stake` pull of `a` would revert on insufficient balance. So a taxed ingress reverts rather than mis-mints — acceptable, but it means **the route requires an untaxed caller→SY hop** (neither hook nor SY is an AMM pair, so the tax predicate is false for the hook path; this configured-state claim is inference pending G1).
  - R1's `net.transfer(receiver, out)` inside staking is likewise nominal: if `receiver` were a mapped taxed pair without exemption, the receiver would get less than `minTokenOut` without a revert. The hook receiver is not an AMM pair (inference; verify configured `isTaxedPair`/exemption state under G1). The hook should still measure its own NET/sNET receipt delta per plan §7.1 step 6 ("measure actual receipts/costs"), because the SY gives no delta guarantee.
- Receipt measurement obligation (consequence for the hook): since SY amounts are nominal, the hook's BasicVaultRepo post-route full-set sync (PRD §6.3) is the authoritative receipt measurement; quoted-vs-actual deltas must be reconciled there, not inside the SY call.

## 6. Fixed-state inverses for exact-output routes (derivation from observed formulas)

All four conversion branches are **linear in the converted amount at fixed index** with a single floor. For output target `y > 0` (9-dec native) and index `i` (9-dec) fixed at the projected state:

| Route | Forward `F(x)` | Minimal inverse | Verification |
| --- | --- | --- | --- |
| R1 exact NET out | `floor(s × i_sync / 1e18)` | `s_min = ceil(y × 1e18 / i_sync) = floor((y×1e18 − 1)/i_sync) + 1` | check `floor(s_min × i_sync / 1e18) ≥ y` and `floor((s_min−1) × i_sync / 1e18) < y` |
| R2 exact sNET out | `floor(s × i_cur / 1e18)` | same form with `i_cur` | same two checks |
| D1 exact shares out (rarely needed) | `floor(a × 1e18 / i_post)` | `a_min = ceil(s_target × i_post / 1e18)` | forward + minimality checks |
| D2 exact shares out | `floor(a × 1e18 / i_cur)` | same form with `i_cur` | same |

Properties (derivation, high confidence): monotonic non-decreasing in the converted amount, so the ceil-form is the unique minimal integer input; the two forward checks must still be executed in-code (plan §6.4's "verify the forward integer result" row applies). Checked-arithmetic domain: `y × 1e18` with `y ≤ type(uint128).max` (sNET supply cap) stays below 2^188, and `s × i` stays below ~2^188 for any representable share supply — 256-bit checked arithmetic is sufficient with `i > 0`; document `i = 0` as a domain fault (index starts at 1e9 and is monotone non-decreasing under the rebase formula, so `i = 0` indicates broken dependency, not a quote of zero). `y = 0` inverts to 0 but base-level zero-amount reverts make exact-zero routes no-ops to reject at the wrapper.

Fixed-state requirements for the inverse inputs:

- R1 inverse must use `i_sync = _syncedIndex()` evaluated against the **same snapshot** the Weighted quote used (plan §6.4: "same projected state"). Because `_syncedIndex` is a view over `staking.epoch()`, `sNet.index()`, `totalSupply()`, `balanceOf(staking)`, any intervening epoch settlement, stake/unstake, or rebase changes it. Previews are same-state projections only; execution protection is `minTokenOut`/`minSharesOut`, **not** the preview (consistent with PRD §4.5's Pendle preview caveat, which this compilation confirms structurally: previews cannot bind state).
- D1's effective index is the **post-stake** index; the inverse must use the projected post-stake index (= `_syncedIndex()` when ≤1 epoch overdue, else current). This is the same projected-state discipline, applied to ingress.
- The sNET-branch (R2) inverse deliberately uses the **stale** index; if the route intends post-rebase value it must settle the epoch first (permissionless `rebase()`) or choose R1.

## 7. Integrating existing Weighted quotes with held/net-claimable SY — coordinates vs funding

Observed plan/PRD baseline (preserved, not re-derived): pricing uses `BalancerV3WeightedPoolQuote.computeOutGivenExactInAfterFee` (net input `mulDown(amountIn, ONE−fee)`, zero-in/zero-fee-adjusted returns 0; `Quote:14–32`) and `computeInGivenExactOutBeforeFee` (WeightedMath inverse, then a **single** `divUp` gross-up; `Quote:34–49`), with the V4 native wrapper supplying scale-up/descale and exactly one fee gross-up (plan §6.4). sNET pricing rates the SY book; NET pricing uses the §7.1.2 PLP/YT zap-out (PRD §6.1). Funding for **both** ordinary NET and sNET outputs is the one shared eligible SY budget (PRD §6.2, R40, R49).

Proposed integration discipline (specification proposal — inference from the observed formulas plus existing plan text; no new economics):

1. **Quote in the pricing coordinate, never in raw SY.** The Weighted helper consumes rated-WAD balances/weights and yields the requested NET or sNET output `y` (9-dec native at the selected boundary). `y` is a pricing result; it does not determine the SY debit.
2. **Convert output → SY debit independently.** Compute `d = ceil(y × 1e18 / i_branch)` per §6 with the branch index matching the chosen redemption: `i_sync` for NET output (R1), `i_cur` for sNET output (R2). Both indexes are read off the same coherent snapshot as the quote. This is the only place pricing coordinates touch SY units; the PLP/YT-derived NET valuation never enters the funding path (PRD §6.1 "Pricing is not funding").
3. **Budget check against eligible SY.** Require `d < E` where `E` = accounted eligible SY = held SY (BasicVaultRepo raw snapshot of the registered SY token) + net-claimable SY (Pendle YT/market interest claims denominated in SY, receivable ledger) − exclusions (fee payables, segregated principal-exit SY, booked obligations). Strict inequality leaves a **positive native SY remainder** after actual claim fees/redemption (plan §6.4 final paragraph); there is no percentage reserve floor and no complete drainage.
4. **Held first, claim only if short.** If held SY `H ≥ d`: no claim; redeem `d` with `minTokenOut = y`. If `H < d`: claim exactly the hook's available Pendle interest (SY-denominated) once — **not** via the SY's empty `claimRewards` (§2) but via the market/YT claim path — reconcile the receivable ledger `(E, R) → (E + c, R − c)` (PRD §6.3), forward non-interest reward tokens to current `feeTo()` under the isolated best-effort exception, then **recompute** `E` and the branch index from the new state (the claim itself does not change the index, but epoch settlement or prior route steps may have; recompute rather than reuse stale `i_branch`). Re-check `d < E` with the recomputed values, then redeem.
5. **State-change recomputation.** Any state transition between quote and redeem (claim, epoch settlement, rollover, another nested route spending the shared budget) invalidates both `y`'s funding assumption and `i_branch`; the route re-derives `d` at the post-claim snapshot before executing the redeem. Sequential NET-then-sNET operations draw down one budget, so the second operation's snapshot must reflect the first's actual debit (PRD §6.2 final paragraph).
6. **Rollback.** If `H + claimable < d`, or the claim delivers less than required, or the SY redeem reverts (insufficient SY sNET custody, pause, `minTokenOut`), the entire invoking operation reverts — no partial payout, no claim ticket, no principal liquidation (PRD §6.2 step 5, plan §6.4). The SY's atomicity (§5) makes partial SY-side settlement impossible; the hook must mirror that at route level.
7. **Fee discipline.** The Weighted fee gross-up happens exactly once inside the helper (`divUp`); the SY conversion has **no fee** (pure index arithmetic — observed fact: no fee term in any branch). Do not add an SY-side haircut, and do not gross up the already-grossed Weighted input again (plan §6.4). NET FoT, where configured, is modeled only in the SE (PRD §8), not re-applied around SY calls.

This satisfies the fixed caller contract of plan §6.5 points 1–6 and adds the missing conversion bodies those points anticipated.

## 8. Finite branch-specific source/state dependencies (observed + inference)

| Branch | External reads | External writes | Configured-state assumptions to verify under G1 |
| --- | --- | --- | --- |
| D1 (deposit NET) | `sNet.index()` post-stake | `net.transferFrom(caller→SY)`; `staking.stake` (re-pull, epoch settle, oracle checkpoint, distributor pull) | caller→SY hop untaxed; SY approvals live (`_safeApproveInf` at init, EXTRACT:72–73); warmup = 0; staking enabled |
| D2 (deposit sNET) | `sNet.index()` | `sNet.transferFrom(caller→SY)` | none beyond token behavior; no epoch settle |
| R1 (redeem NET) | `_syncedIndex` ← `staking.epoch()`, `sNet.index()`, `totalSupply()`, `balanceOf(staking)` | burn; `staking.unstake` (epoch settle; `sNet.transferFrom(SY→staking)`; `net.transfer(receiver)`) | SY sNET custody ≥ out (else revert); receiver hop untaxed vs `minTokenOut` nominal check; mirror constants match deployed sNET |
| R2 (redeem sNET) | `sNet.index()` | burn; `sNet.transfer(receiver)` | SY sNET custody ≥ out; sNET transfer dust (`floor(gons/GPF)` quantization, `StakedNET.sol:58–60,127–137`) |
| P1–P4, E1 | as above, read-only | none | same-state snapshot discipline; no binding power |
| Claims feeding the budget | Pendle market/YT `userInterest`/claim paths for the hook address (PRD §7.1.3) | claim in SY; forward other rewards to `feeTo()` | SY `claimRewards` is empty (EXTRACT:309–333) — claims come from market/YT, not the SY |

Finite and bounded: every branch touches at most the four sNET/staking reads, one token pull/push, and one staking call. No unbounded loops exist in the SY; epoch catch-up is externally driven one-per-call (§4).

## 9. Exact proposed plan §6.5 changes (text-level proposal; not applied)

1. **Replace the "Not yet read" bullet** (plan v0.7, line 437) with: "Read from the decoded bundle: `_deposit`/`_redeem` (branches D1/D2/R1/R2), `_previewDeposit`/`_previewRedeem` (P1–P4), `exchangeRate` (E1), `_syncedIndex`, token lists, `assetInfo`/`pricingInfo`, supply-cap and base-level guards in `SYBaseUpgV2`, `TokenHelper`, `PendleERC20Upg`, `TokenWithSupplyCapUpg`, `IStakedNet`, `IStakedNetStaking`. Branch table, units, index semantics and inverses are recorded in §6.5's new conversion table. Remaining unread: decimals-wrapper implementation (absent from the compilation; interface only) and deployed proxy configuration."
2. **Replace the "Next source task" sentence** (line 439) with: "Conversion bodies are mapped. L3 remains open only for: (a) deployed-equivalence evidence (Sourcify decode ≠ fresh runtime check; local NetNet reference ≠ deployed StakedNET/Staking); (b) configured state — warmup epochs, tax/exemption predicates on the hook/SY/staking/receiver hops, approvals, pause/ownership, supply cap; (c) execution/parity tests in §11. No new extraction campaign."
3. **Insert the §1–§2 branch table and §6 inverse table of this report** into §6.5 (or as a referenced annex), and **append two rows to §6.4's forward-stage table**: "SY exact NET output — `ceil(y×1e18/i_sync)` with forward+minimality verification; index from `_syncedIndex()` at the quote snapshot" and "SY exact sNET output — same form with current `index()`; stale-index branch is deliberate".
4. **Amend fixed caller contract point 4** to record the now-observed one-epoch-per-call semantics and the D2/R2 stale-index asymmetry, and **point 6** to record that minOut compares nominal computed amounts (no delta measurement inside the SY), making hook-side receipt measurement via BasicVaultRepo mandatory.
5. Record in §6.5 that `claimRewards`/`getRewardTokens` are empty in this compilation: "net-claimable SY" is funded by market/YT interest claims, and the wrapper-implementation absence does not block any selected route (the hook never holds wrapper tokens; SY mint/redeem only touch NET/sNET custody).

These are documentation edits for a later authorized documentation task; this report does not apply them.

## 10. Unexecuted test cases (proposed; none run)

1. **Branch differential**: P1–P4 vs D1/D2/R1/R2 realized amounts at (a) no overdue epoch; (b) one overdue epoch with queued profit; (c) one overdue epoch, zero profit; (d) `circulating == 0` (all sNET at staking); (e) supply within 1 unit of `type(uint128).max` cap.
2. **Mirror exactness**: realized post-stake/post-unstake `index()` vs `_syncedIndex()` across randomized `queuedProfit`, `supply`, `circulating` — must be bit-equal, including the two-floor structure and cap.
3. **Multi-epoch**: two epochs overdue → one `redeem(NET)` advances exactly one epoch; `amountTokenOut` equals the one-epoch projection; a second call advances the second.
4. **Stale-index asymmetry**: overdue+profit state → R2 (sNET out) pays strictly less than R1 (NET out) for equal shares; document the branch choice; after permissionless `rebase()`, branches reconverge.
5. **Inverse minimality**: for fuzzed `y`, `i`: `F(s_min) ≥ y`, `F(s_min − 1) < y`, zero-domain rejection, checked-arithmetic bounds near `uint128` supply.
6. **Custody/receipt**: `burnFromInternalBalance=false` from hook shares; `true` burns SY-held shares only; taxed-ingress revert on D1 (shortfall at `stake`); nominal-vs-received NET delivery on R1 when receiver hop is taxed (route-level expectation: configured untaxed); hook-side measured delta vs nominal.
7. **Guard paths**: `SYZeroDeposit`/`SYZeroRedeem`, `SYInsufficientSharesOut`/`SYInsufficientTokenOut`, invalid tokens, paused mint/redeem, supply-cap mint revert, zero-circulating rebase skip.
8. **Funding sequence**: held-sufficient → no claim; held-short → exactly one claim, receivable ledger `(E,R)→(E+c,R−c)`, recompute and redeem; claim shortfall → full rollback with zero net token/share/ledger change; positive native SY remainder `E − d > 0` after success; sequential NET-then-sNET routes share one budget without double-spend.
9. **Fee discipline**: Weighted exact-out gross-up applied once (`divUp` output not re-grossed); SY stage adds no fee; end-to-end exact-output route equals composed per-stage inverses within justified per-stage rounding only.
10. **Warmup/exemption configured-state checks** (fork-tier, G1-gated): deployed warmup = 0; `isTaxedPair`/`isTaxExempt` for hook/SY/staking/receiver; approvals and pause state.

## 11. Counterarguments, uncertainties, missing evidence

- **Deployed equivalence (uncertainty, high impact).** All index/rebase mirror claims rest on the local reference (`StakedNET.sol`, `Staking.sol`) matching the deployed contracts the SY reads. The SY compilation hardcodes mirrored constants (EXTRACT:47–51); if the deployed sNET uses different `INITIAL_FRAGMENTS`/`TOTAL_GONS`/`MAX_SUPPLY` or a different rebase formula, `_syncedIndex` mis-projects and R1/D1 mis-price. This is G1 evidence work, not readable from the SY bundle.
- **Extraction trust tier.** The manifest's round-trip/hash agreement validates decode fidelity of a downloaded Sourcify payload; it is not a block-pinned bytecode comparison, and the proxy's current implementation slot is service-resolved, not independently verified here.
- **Wrapper absence.** The 18-decimal wrapper implementation is absent; SY decimals = 18 is inferred through the constructor's `IERC20Metadata(_yieldToken).decimals()` call plus the `getOrCreate(…, 18)` argument (high confidence), but wrapper transfer/mint semantics are unobserved. Per operator instruction this blocks nothing selected.
- **Multi-epoch sNET-branch drift (minor).** R2/D2 never advance epochs; with ≥1 overdue profitable epochs the sNET coordinate lags. Bounded by queued profit per epoch; routes that care must settle first. Not a solvency issue for the SY (custody rebases regardless).
- **Nominal minOut (§5).** A configured tax on the receiver hop could defeat `minTokenOut` silently. Mitigation is configured-state verification plus hook-side delta measurement; not an SY change.
- **Speculation avoided:** no claim is made about current `epoch()`, `index()`, cap proximity, warmup, exemption sets, or any live balance. No 1:1 share assumption is made anywhere; no new Weighted inverse is proposed; no substitute SY is proposed.
- **L3/G1 status:** this report completes the conversion-body inspection task named in plan v0.7 line 439, but does **not** close L3 or G1; §9 items 2(a)–(c) and §10's unexecuted tests remain.

## 12. Confidence summary

| Claim | Confidence |
| --- | --- |
| Branch table, formulas, guards, empty reward surface (§1–§2) | High — direct decode of the verified compilation |
| Index projection structure incl. floors/cap/zero-circulating (§3, SY side) | High |
| Mirror equivalence to deployed sNET/Staking | Unproven — local reference only; G1 |
| One-epoch-per-call advancement; stake/unstake ordering (§4) | High for local reference; deployed equivalence unproven |
| Custody/pull/nominal-minOut semantics (§5) | High for the SY; tax/exemption configured state unverified |
| Inverse formulas and domain (§6) | High (linear fixed-state arithmetic) |
| Integration discipline (§7) | Specification proposal consistent with PRD/plan; no execution evidence |
| Test cases (§10) | Unexecuted; no pass claimed |
