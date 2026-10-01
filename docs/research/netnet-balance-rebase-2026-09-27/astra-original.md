# Astra — ORIGINAL L1 reference-reuse investigation

Access date: 2026-09-28 (session environment). Continuing council-astra, assigned `openai/gpt-6-astra`; routing identity, not independent provider attestation. The authorized corrected-path read of `src/perp/WrappedStakedNET.sol` succeeded normally. No assertion that infrastructure was repaired or that the earlier guard was caused by the wrong path. No current-round peer artifacts read. Only this report written; no execution, tests, RPC, browser, code/configuration changes or delegation.

## Finding

**Balance/share rebasing is established technology. L1 must not be described as its impossibility.** The inspected references supply useful exact-unit and share-denominated conversion patterns. However, they do not all make the same guarantee: NetNet sNET uses an explicitly refreshed gon divisor; wsNET and several Pendle conversions accept floor loss; Pendle's rewards and PY accounting use explicit indexes. None of these inspected implementations alone supplies the complete selected live-custody B/U plus fixed-native-bond-principal algorithm.

I narrow my previous position further: a safe share-budget reward claim can be derived without enumerating holders. The unresolved issue is not every reward withdrawal; it is matching the selected native principal/reward promises for all required transitions, particularly admission, with a specific representation and dust rule.

## 1. What their code actually does

Local abbreviations: **N**=`lib/crane/contracts/protocols/pol/net/src/`; **P**=`lib/crane/contracts/protocols/perps/pendle/core/`.

### NetNet sNET: exact native transfers at an explicit gon divisor

`N/StakedNET.sol:25–40,58–77,83–99,127–136`:

- `T=MAX_UINT256-(MAX_UINT256 mod 5_000_000_000e9)` fixed total gons; initial fragments `5e18`; K=`gonsPerFragment` initially T/5e18.
- Account display `floor(g/K)`; transfer x moves exactly xK gons. Therefore `floor((g±xK)/K)=floor(g/K)±x` at the same K. This is the actual exact-native normalization solution, not small integer shares.
- Authorized rebase computes `r=floor(profit*totalSupply/circulating)`, caps new total at uint128 max, then **writes** `K=floor(T/newSupply)`. Comments saying aggregate growth is “exact” must be read with those floors and cap.
- Transferring the entire displayed balance leaves `g mod K` gons; no special full-exit fraction retirement or final-holder custody sweep appears here.

`N/Staking.sol:88–125,134–150`: stake settles a due epoch then transfers nominal x NET and sends x sNET; unstake receives x sNET and sends x NET. It does not derive shares from `NET.balanceOf(staking)`. With zero circulation it retains queued distribution; it does not award queued funds to newly minted ownership shares immediately. Warmup claims delete their entry, send `floor(entry.gons/K)` and do not preserve a separate claimant remainder.

**Reuse boundary:** xK debit is suitable when K is the authoritative exact conversion unit. Recomputing K from B/U and substituting it is not algebraically equivalent to `floor(B*u/U)`. The explicit index/cap/inventory behavior cannot silently replace PRD §10.2.

### NetNet wsNET: static shares, rounded index conversion

`N/perp/WrappedStakedNET.sol:48–85`: wrap x mints `floor(x*1e18/I)` shares; unwrap m burns exactly m and pays `floor(m*I/1e18)`, I=`sNET.index()`. No balance-ratio normalization, remainder ledger, minimum minted-share check or special last-holder sweep. Full share exit can leave raw sNET custody dust.

High-precision example: at I=1,500,000,000, wrapping one whole sNET (`x=1e9`) gives `666666666666666666` ws units; unwrapping all gives `999999999` sNET units, one native unit short. This index is consistent with the StakedNET rebase algebra: from its initial state with 2e9 circulating fragments, a permitted `rebase(profit=1e9,...)` computes total fragments7.5e18 and index1.5e9; the enormous actual gon precision leaves the displayed index at that integer. This is a contract-arithmetic example, **not proof current Distributor policy supplies that profit or an executed live trace**.

Thus wsNET intentionally promises conversion of shares at an index, not lossless native round trips. Its successful operation is not evidence for an exact native principal guarantee.

### Pendle SY: static adapter shares, implementation-specific rounding

`P/StandardizedYield/SYBase.sol:37–76,85–105` transfers input, calls implementation `_deposit`, checks minShares, mints returned shares; redemption burns exactly supplied shares, calls `_redeem`, checks minTokenOut. The base imposes neither B/U nor exact native round-trip recovery, and has no generic last-holder sweep.

Concrete implementations:

- `implementations/PendleWstEthSY.sol:35–86`: wstETH↔SY is1:1; stETH routes delegate wrap/unwrap; rate is `getPooledEthByShares(1e18)`. Live pooled-asset/share conversion belongs to the underlying, not a refreshed SY balance.
- `implementations/AaveV3/PendleAaveV3SY.sol:27–79`: deposit converts via normalized income; redemption pays `floor(shares*index/1e27)`. **Important:** `AaveAdapterLib.calcSharesFromAssetUp` (:16–17) calls `WadRayMath.rayDiv`, whose :76–90 implementation is **nearest, half-up**, `(assets*1e27+floor(index/2))/index`, not mathematical ceiling. Name-based reuse would be wrong. Underlying Aave normalization is essential; changing the denominator to B/U is not validated by this adapter.
- Public `PendleDecimalsWrapper.sol` wraps x into `x*10^(18-d)` exactly; unwrap burns m and pays `floor(m/10^(18-d))`. `sweep()` explicitly transfers surplus over converted totalSupply to the factory's dustReceiver. This is decimal normalization, not rebasing or authorization to import a new dust recipient.

### Pendle indexes are not a hidden live-B/U principal solution

`P/RewardManager/RewardManager.sol:27–49` uses held reward-token balance **deltas**, then writes `index += floor(accrued*1e18/totalShares)` and lastBalance. At zero shares it still advances lastBalance without distributing the receipt. `RewardManagerAbstract.sol:35–64` checkpoints only affected users, flooring their reward; no holder enumeration. Rounded residuals are not explicitly reallocated by that update. `SYBaseWithRewards.sol:7,78–95` requires yieldToken not be rewardToken and updates rewards on transfers.

`P/YieldContracts/PendleYieldToken.sol:342–355,397–404` mints PY with floor SY→asset conversion, redeems with floor asset→SY, and stores `max(exchangeRate,previousIndex)`. `SYUtils.sol:7–20` provides explicit down/up helpers. These are normalized asset claims with rounding, not the custom NFT's unchanged fixed-native principal ledger.

## 2. Constructive live-B/U candidate and precise boundary

Ordinary share receipt mechanics are straightforward: at B,U>0, fund x, mint `m=floor(xU/B)`; redeem specified d shares for `y=floor(Bd/U)` and burn d. Poststate is `(B+x,U+m)` or `(B-y,U-d)` respectively. Both preserve or increase the backing/share rate for old remaining shares because m≤xU/B and y≤Bd/U. First B=U=0 can seed `x*Q` shares. Full share redemption burns all of that account's u, paying its displayed balance; no global loop or reward index is needed.

**This is a usable share-denominated design, not yet a drop-in fixed-principal bond implementation:** the new holder can initially display x−1, and a share redemption pays its floored conversion, not every independently requested native amount.

### Safe reward-share budget: progress beyond the old ceil-debit example

Given a funded position u and remaining principal P with `floor(Bu/U)≥P`, reserve `p=ceil(PU/B)` shares. Only `u-p` is a reward-share budget. Let `x=floor(B*(u-p)/U)`. If x=0, keep the shares—do not burn them for zero. Otherwise debit the **minimal** `d=ceil(xU/B)`, which satisfies d≤u−p, and pay x. Since d≥xU/B, remaining backing/share rate cannot decrease; at least p shares remain, hence poststate principal stays backed. No perholder loop or index refresh.

This may leave a last native unit of the independently computed `floor(Bu/U)-P` temporarily unavailable as an exact-native payout. It is not safe to call that unit paid or erase it. This construction resolves principal safety of accepted share-budget claims; it does **not** prove parity with reference `_claim`'s entire native `rewardsDue` or establish the missing admission rule.

A high-precision, ordinarily reachable **candidate B/U** sequence makes the distinction clear. Seed two positions with principal2 each, `u=2Q`, U=4Q, B=4; fund ordinary reward2, giving B=6. Each displays3 with principal2. At Q=10^27, exact-native reward1 with d=`ceil(2Q/3)` leaves the claimant:

`floor(5*(2Q-d)/(4Q-d))=1`, below principal2.

This is not the low-share B3/U2 toy state. The safe reward-share budget instead quotes zero and preserves the position intact. It is a sequence reachable under the candidate's own seed/funding rules, **not a NetNet sNET counterexample**: sNET's exact xK transfer prevents that particular error. Actual fee configurations need their own mapped trace.

PRD §10.2:710,718,720 allows native rounding/position-local dust, so a blanket claim that all fractional rewards must be paid exactly is too strong. But §10.3:726–737 preserves principal/reward separation; `contracts/vaults/detf/common/core/DETFFundedStakingMath.sol:110–116` explicitly reverts when staking value is below remaining native principal and defines rewards as value minus that principal. Merely resetting principal to newly displayed shares' value would erase part of separately computed funded principal. Locking all originally minted principal shares instead would lock their yield too. Neither is an established semantics-preserving reuse solution.

## 3. Recipient translation and zero-share handling

Reuse `DETFSeigniorageShareLib.sol:18–33` and funded-plan :198–227: O includes all funded receipt shares, including old recipient receipts; Wf/Wc are separate persistent, nonredeemable weights. Top up toward `floor(floor(O*WAD/(WAD-f-c))*f/WAD)` and its creator counterpart, never reduce on exit. Allocate A through the source two-stage reward-per-share floors to S,F,C,D, not fixed fA/cA.

For D=0, exact rational receipt issuance is `mF=FU/(B+S)`, `mC=CU/(B+S)`. This allocates **new reward backing only**. Integer floor mF/mC preserves old holders' aggregate rate but does not guarantee each intended native F/C is immediately redeemable; rounding residue needs a truthful ownership treatment, not double allocation. Standing weights cannot themselves be minted as ownership of old B.

At U=0,Bpre=0 with surviving weights20/30 and reward100: allocate F40,C60 and seed corresponding funded shares. Do not reject simply because the reward transfer makes B positive. At U=0 with pre-existing attributed funds, honor their established ownership first. Neither NetNet's queued-emission rule nor Pendle's zero-supply reward-index behavior supplies the required live-B/U treatment of unrelated positive B; a new depositor/recipient grant or sweep would change rights. I have not derived a complete compatible orphan/dust branch from these references.

## 4. Evidence and disposition

Current PRD v0.30 §10.2 and plan v0.2 §9/L1 directly read. CLAUDE/canonical architecture and adversarial skills read; prior catalog/source guidance retained. NetNet local pragmas ^0.8.24; Pendle local variants ^0.8.0/^0.8.17/^0.8.23. Local snapshots and public main-branch source are not runtime/version attestations.

Context7 first resolved `/websites/pendle_finance`; its query was too generic for the arithmetic, so official documentation/source was fetched:

- https://docs.netnet.capital/official-channels — publishes sNET/Staking/wsNET bindings, not deployed-code equivalence.
- https://docs.pendle.finance/pendle-v2-dev/Contracts/StandardizedYield
- https://docs.pendle.finance/pendle-v2-dev/Contracts/StandardizedYield/DecimalsWrapper
- https://raw.githubusercontent.com/pendle-finance/pendle-sy-public/main/contracts/core/misc/PendleDecimalsWrapper.sol

Actual external NetNet SY was **not identified/verified** by this bounded search. One guessed official-repository `implementations/NetNet/PendleStakedNETSY.sol` fetch returned404; not retried. The official implementation-directory listing was too large for full returned context. Search returned generic Pendle documentation, not a deployment-bound NetNet implementation. This is missing evidence, not proof no such adapter exists.

**Confidence:** high in inspected arithmetic, rounding distinctions and the safe reward-share-budget proof; conditional on input/funding invariants. No executed reachability, deployed SY, or complete finite-share fixed-principal solution established. Withdraw any interpretation of prior L1 as “rebasing is unsolved.” Retain only the exact integration mismatch: selected live B/U, computed native principal and source-native reward claims are not simultaneously demonstrated by copying these particular reference conversions. Do not close it by importing an explicit index, redefining funded principal downward, or pretending decimal scaling eliminates rounding.
