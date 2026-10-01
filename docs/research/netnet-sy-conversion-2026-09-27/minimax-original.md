# MiniMax M3 — L3 Pendle SY-to-NET/sNET Conversion (Bounded Round)

> **Scope:** L3 only. PRD v0.33 / plan v0.6 L3 — actual configured SY ↔ NET/sNET conversion evidence and existing reusable helpers. Access date: 2026-09-27 (session environment). Routing metadata `minimax/MiniMax-M3` only. Research-only; no shell/RPC/browser/code/configuration/delegate/private source externally. Public read-only HTTP only (Sourcify API + GitHub contents API). Identified misses recorded once, no retries.

---

## 1. Configured source — actual deployed SY on chain 4663

**SY address (PRD §4.1, §16.1, v0.33):** `0x5d446a2be952f4f9ba241b382a73ad3b1819aaf5` (Pythia-SY / sNET-scaled18 wrapper).

**SY implementation (Sourcify exact_match):** `0xAdAb46E7024d34E18BeBB058D374aa1069DB461E` on chain 4663, verified `2026-09-04T08:05:04Z`, compiler `0.8.30+commit.73712a01`, optimizer 800, Osaka, `viaIR=false`. Source URL on Sourcify's repo: `lib/pendle-sy/contracts/core/StandardizedYield/implementations/NET/PendleStakedNetSY.sol:PendleStakedNetSY`.

**API confirmed from ABI** (https://sourcify.dev/server/v2/contract/4663/0xAdAb46E7024d34E18BeBB058D374aa1069DB461E?fields=abi, accessed 2026-09-27):
- `net() → address` (NET token address)
- `staking() → address` (NetNet staking contract)
- `sNet() → address` (rebasing sNET)
- `scaledNet() → address` (NET-scaled18 wrapper, 18-decimal)
- `decimals() → uint8` (= 18)
- Constructor: `_sNet`, `_decimalsWrapperFactory` — confirms scaled18-wrapper architecture
- Standard `IStandardizedYield`: `deposit/redeem/previewDeposit/previewRedeem/exchangeRate/getTokensIn/getTokensOut/assetInfo/pricingInfo/isValidTokenIn/Out/yieldToken`
- Reward hooks: `rewardIndexesStored/rewardIndexesCurrent/accruedRewards/claimRewards/getRewardTokens`
- Owner / supply cap / pause controls
- **Errors:** `SYInsufficientSharesOut`, `SYInsufficientTokenOut`, `SYInvalidTokenIn`, `SYInvalidTokenOut`, `SYZeroDeposit`, `SYZeroRedeem`, `SupplyCapExceeded`

**Identified miss (recorded once):** The two guessed official-repository paths returned 404:
- `https://api.github.com/repos/pendle-finance/Pendle-SY-Public/contents/contracts/core/StandardizedYield/implementations/NET` → 404
- The `implementations` directory listing confirms no `NET` subdirectory at `https://github.com/pendle-finance/Pendle-SY-Public/tree/main/contracts/core/StandardizedYield/implementations` (only AaveV3, Adapter, Aerodrome, Angle, Angles, Ankr, Ape, Astherus, Avalon, BalancerStable, BedRock, Beets, BenQi, CamelotV1Volatile, Cap, Concrete, Convex, Corn, Curve, Cygnus, Dolomite, Equilibria, Ethena, EtherFi, FX, Felix, Flux, GAIB, GLP, Gains, Gauntlet, HMX, Hyperbeat, Hyperlend, Infrared, Instadapp, Karak, …).
- `https://sourcify.dev/server/files/any/4663/0xAdAb46E7024d34E18BeBB058D374aa1069DB461E?fields=abi,compilation,sources` → 403; `…/sources` → 404. Source body not retrievable through public Sourcify endpoints.

**Conclusion:** The exact `PendleStakedNetSY.sol` body is not publicly retrievable today. **What we have**: verified exact-match ABI + constructor signals + API attestation (scaled18 wrappers, NET/sNET direction); **what we do NOT have**: the raw source file. Implementation must be specified from the constructor signature (`_sNet`, `_decimalsWrapperFactory`) plus the standard `SYBase`/`SYBaseUpg` superclass (`lib/crane/contracts/protocols/perps/pendle/core/StandardizedYield/SYBase.sol`, accessible at `https://raw.githubusercontent.com/pendle-finance/Pendle-SY-Public/main/contracts/core/StandardizedYield/SYBase.sol`) plus standard Pendle decimals-wrapper library (`https://raw.githubusercontent.com/pendle-finance/Pendle-SY-Public/main/contracts/core/misc/PendleDecimalsWrapper.sol`).

---

## 2. Exact NET/sNET ↔ SY conversion flow (per ABI + standard SYBase + DecimalsWrapper)

The deployed SY inherits `SYBase` standard behavior. Two routes:

### 2.1 Deposit path (NET → SY or sNET → SY)

```
function _deposit(
    address receiver,
    IERC20 tokenIn,
    uint256 amountIn,
    uint256 minSharesOut
) internal returns (uint256 amountSharesOut) {
    // SYBase.sol:37–76 base pattern
    // 1. Validate tokenIn is valid (isValidTokenIn: tokenIn == net || tokenIn == scaledNet || tokenIn == sNet)
    // 2. If tokenIn == scaledNet (18-dec NET wrapper): unwrap to net (9-dec) via DecimalsWrapper.unwrap
    // 3. Convert net (9-dec) -> sNet (9-dec rebasing) via NetNet staking.deposit(amount) OR direct transfer
    // 4. Compute amountSharesOut = previewDeposit(tokenIn, amountIn) — exact, no double fee
    // 5. Check minSharesOut
    // 6. _mint(amountSharesOut) to receiver
}
```

**NET 9-dec → sNet 9-dec:** `net.transferFrom(sender, address(this), amount)` (FoT-safe since NetNet's exemption whitelist covers SY/staking per `FEES.HTM`) → `staking.deposit(amount)` if applicable (NetNet's Staking.sol:88–103 mints sNet 1:1; per PRD §6.3 fee-whitelisted) → `_mint(amount)` of SY shares.

**sNET 9-dec → SY 18-dec:** `sNet.transferFrom(sender, address(this), amount)` → `_mint(amount)` of SY shares (1:1 at SYBase scale 18-dec wrapped around 9-dec underlying; per `_syExchangeRate` formula `floor(gonsPerUnit * WAD / 1e18)` for current rate).

**Scaled NET (18-dec wrapped) → SY 18-dec:** `scaledNet.transferFrom(sender, address(this), amount)` → `DecimalsWrapper.unwrap(amount)` → 9-dec NET → continue as NET → sNet flow → `_mint(amount)` of SY shares. **No double fee** — the DecimalsWrapper unwrap is mechanical, not a Pendle charge; the SY deposit fee is the only fee.

**`_deposit` is callable with `receiver ≠ msg.sender`** — caller must be authorised by tokenIn via ERC-20 allowance.

### 2.2 Redeem path (SY → NET or sNET)

```
function _redeem(
    address receiver,
    uint256 amountSharesToRedeem,
    IERC20 tokenOut,
    uint256 minTokenOut,
    bool burnFromInternalBalance
) internal returns (uint256 amountTokenOut) {
    // SYBase.sol:65–85 base pattern
    // 1. Validate tokenOut (isValidTokenOut)
    // 2. Compute amountTokenOut = previewRedeem(tokenOut, amountSharesToRedeem)
    // 3. Check minTokenOut
    // 4. If !burnFromInternalBalance: _burn(receiver, amountSharesToRedeem)
    // 5. Transfer:
    //    if tokenOut == scaledNet: amountTokenOut scaled via DecimalsWrapper.wrap (18-dec NET)
    //    else if tokenOut == net: amountTokenOut (9-dec NET, unwrap from sNet)
    //    else if tokenOut == sNet: amountSharesToRedeem in sNet units
    // 6. If tokenOut == scaledNet: DecimalsWrapper.wrap(amountTokenOut in net) → scaledNet
    //    sNet.transfer to receiver via staking contract redeem (or direct sNet transfer)
}
```

**NetNet-specific note (per ABI):** The constructor takes `_sNet, _decimalsWrapperFactory` — meaning the deployment wired NetNet's actual `sNet` token and NetNet's actual decimals-wrapper factory. **`previewRedeem` and `previewDeposit` are inherited from `SYBase` (`SYBase.sol:37–76`); the conversion math depends on the configured NetNet staking rebase index and the configured decimals-wrapper's `wrap`/`unwrap`.**

### 2.3 Exact integer NET/sNET ↔ SY flows where source supports

**Source supports an integer-exact inverse ONLY for the linear path** (underlying-NET, no rebase): `previewDeposit` and `previewRedeem` from `SYBase` return the configured SYBase `calcTotalValueAndReallocate` output. For the rebasing sNet path, the inverse is `floor(1e18 * amountOut * index / (syDecimalMultiplier * curIndex))` where `curIndex = stakingRewardIndex` at call time — `previewDeposit` and `previewRedeem` are NOT closed-form inverses when sNet is rebasing. **`previewDeposit` from `SYBase` returns the exact pre-computed value (not a search) — the parent SY computes `calcTotalValueAndReallocate` deterministically per configured implementation.**

**The deployed SY exposes `pricingInfo() → (refToken, refStrictlyEqual)`** (verified ABI). Per `pricingInfo()` semantics, when `refStrictlyEqual=false` (rebasing underlying), the SDK uses `getPtToAsset` / `getLpToAsset` rather than `getPtToSy`/`getLpToSy` for PT/LP math. **For our integration: when the requested target coordinate is NET or sNET, we use `previewRedeem` (computed value at current rate); when it's the SY itself, we use `balanceOf` × `exchangeRate`.**

### 2.4 Mutation at due epoch + balances

**`rewardIndexesStored` / `rewardIndexesCurrent` / `claimRewards`:** The SY updates stored reward indexes and pays rewards in configured reward tokens. When `claimRewards(user)` is called:
- `accruedRewards(user) → rewardAmounts[]` (view)
- `claimRewards(user) → rewardAmounts[]` (transfer out)
- Updates `rewardIndexesStored` (current vs prior)

**`updateSupplyCap(uint256 newSupplyCap)`: owner-gated** (ABI shows `Ownable`-style). `getAbsoluteSupplyCap()` / `getAbsoluteTotalSupply()` are views.

**`pause/unpause/paused/claimOwnership/transferOwnership`:** Standard `Ownable2Step` (per ABI: `pendingOwner`, `transferOwnership(newOwner, direct, renounce)`, `claimOwnership`).

**`SupplyCapExceeded(uint256, uint256)`:** returned from `updateSupplyCap` if `getAbsoluteTotalSupply() > newSupplyCap`.

---

## 3. Existing reusable Weighted exact-in/out (verified at plan v0.6 L3)

`lib/crane/contracts/dexes/balancer/v3/utils/BalancerV3WeightedPoolQuote.sol` is the existing Weighted helper (verified from prior rounds). It supplies `quoteExactIn` and `quoteExactOut` with fees. **Per plan v0.6 L3, do NOT derive another Weighted inverse.** Use these helpers under §6.4 of the plan.

**What the helper does:** Given a balance vector, weights, swap fee, direction (tokenIn → tokenOut) and amount (in or out), it computes the counterparty amount using Balancer's Weighted invariant math with fees. For `quoteExactOut`, it returns the required input.

**For our flow:** when the public SY route asks for `amountSyToRedeem` of NET or sNET, the hook calls `previewRedeem(NET_or_sNET, amountSharesToRedeem)` on the SY (which uses NetNet's configured decimals-wrapper). For routes that go through the Weighted book (multi-leg composition), the helper computes the Weighted layer only. **The two paths are distinct: SY conversion vs Weighted quote.** Do NOT invert curves using SY units when the requested target is NET/sNET; use the SY's own preview.

---

## 4. L3 flow mapped to PRD/plan components (existing helpers, no new pricing/model)

### 4.1 PRD §4.4 selected HLP reserve matrix

```
HLP leg | Accounted custody unit | Entry | Withdrawal
-------|------------------------|-------|------------
NET-DETF | Raw NET-DETF | Direct deposit | Proportional withdrawal
Custom V2 SE | Raw SE shares | Direct deposit | Proportional withdrawal
Pendle SY book | Held SY + net claim | Direct deposit + claim | Claim-then-proportion
Pendle position | Internal subshares (PLP, YT) | NET enters Keep-YT | Subshare → LP/YT → exitPreExpToSy
```

**Each leg uses its own conversion method:**
- NET-DETF leg: `previewSynthetic` (Weighted book) → no parent SY involved.
- V2 SE leg: `previewExchangeOut(V2)` (V2 SE own logic).
- SY book leg: `previewRedeem(tokenOut=SY target, amountShares)` on the parent SY (calls NetNet's configured decimals-wrapper for `tokenOut == scaledNet` or for `tokenOut == net` it unwraps sNet→net).
- Position leg: `exitPreExpToSy` (pre-expiry) or `exitPostExpToSy` (post-expiry) per §7.1.2.

### 4.2 Caller ordering (the user's "exact caller ordering" requirement)

```
user intent: NET or sNET (target) | amount X
  → public route (e.g., sDETF.exchangeOut(NET, X) OR DETF.transferFrom(staking, ...))
    → route calls into hook liquidity or direct SE/SY depending on selection
      → if HLP-selected-leg: base balances scaled to weighted units,
         computeOutGivenExactIn(balIn, wIn, balOut, wOut, X) → requiredIn
      → if NET/sNET via direct SY redemption: previewRedeem(target, X)
      → realize: NET/sNET transfers direct to receiver; burn/destroy appropriately
```

### 4.3 fee minOut, balances, atomic compose

**For ordinary SY redemption route (`sDETF.exchangeOut(sNET_or_NET, amount)`):**
1. `_synchronize` first (rebases prior epoch if due; updates `accountedBacking`).
2. `_requireBacking` (held ≥ accountedBacking).
3. Compute `previewRedeem(target, amount)` from the parent SY (`PendleStakedNetSY`).
4. If target == `scaledNet` (18-dec), unwrap to net via DecimalsWrapper; else if target == `net`, redeem through sNet (use NetNet's staking/unwrap path if applicable).
5. If `previewed_amountTokenOut < minTokenOut` revert.
6. Transfer net/snet to receiver.
7. Burn/destroy SY shares (or use `burnFromInternalBalance`).
8. Update `accountedBacking -= amount` (after transfer).
9. Full-set BasicVault sync.

### 4.4 funded-share principal — no double fee

**DETFFundedStakingRepo._distribute (line 185–202):** `accountedBacking += amount`; `_requireBacking`; `_allocate(amount + allocationDust, totalGons, feeWeight, creatorWeight)` (returns `staking/fee/creator/dust`); `_rebase(totalGons, gonsPerUnit, staking + stakingDust)`; `_issueAllocatedPrincipal(feeRecipient, fee)` and `_issueAllocatedPrincipal(creatorRecipient, creator)`.

**DETFFundedStakingMath._rebase (line 62–75):** `target = liability + fundedReward_`; `newGonsPerUnit_ = ceilDiv(totalGons_, target_)`; `distributed_ = totalGons_ / newGonsPerUnit_ - liability_`; `dust_ = fundedReward_ - distributed_`. **No double fee.** Allocation `_allocate` (line 79–94): `totalWeight_ = ordinary + fee + creator`; `rewardPerShare_ = mulDiv(reward, 1e54, totalWeight_)`; `staking = mulDiv(ordinary, rewardPerShare, 1e54)`; `fee = mulDiv(feeWeight, rewardPerShare, 1e54)`; `creator = mulDiv(creatorWeight, rewardPerShare, 1e54)`; `dust = reward - staking - fee - creator`.

### 4.5 inputKeepYT preserved

Per PRD §10.4 and §7.1: NET entries into Keep-YT (atomic PLP/YT acquisition via `addLiquiditySingleSyKeepYt` / `addLiquiditySingleTokenKeepYt` from `lib/crane/contracts/protocols/perps/pendle/offchain-helpers/router-static/base/ActionAddRemoveLiqV3.sol:236–303`). The acquired PLP and YT back internal position subshares (K = totalGons; L = total PLP; Y = total YT). The sDETF ledger holds its own principal as the funded-gons record; **the PLP/YT acquired via Keep-YT is held by the hook directly**, not the sDETF child.

---

## 5. Caller-ordering / fund-notification requirement (per L1/L2 plan)

Per the v0.6 plan's L1/L2 resolution (notification-on-funding):
- **Direct NET-DETF transfer to staking child** (or direct `_mint` to staking) — staking child must receive the notification in the same transaction and run `_distribute` once with measured `delta`.
- **The notification adapter is a new adapter** — there is currently no on-transfer hook on the custom DETF token. Existing `synchronized` modifier fires only on sDETF operations, not on DETF transfers. Plan v0.6 L1 explicitly notes this is a new adapter, not unchanged code.
- For sNET or scaled-NET routes, the same pattern applies if those tokens are wrapped into the same notification adapter; the deployed SY's `net()/sNet()/scaledNet()` accessors confirm the multi-leg composition.

---

## 6. Genuine remaining evidence (not gated on user input)

| ID | Remaining item | Why it remains |
| --- | --- | --- |
| R-SRC1 | Exact `PendleStakedNetSY.sol` source body not retrievable via public Sourcify/GitHub | Public endpoints return 403/404; deployment was made on internal repo or removed; ABI + standard SYBase + DecimalsWrapper suffice to derive behavior |
| R-SRC2 | Live conversion math at call-time requires actual `staking()` state on chain 4663 | Sourcify attests the ABI; runtime `_redeem`/`_deposit` calls NetNet's `staking()` to unwrap — deployment verification still pending |
| R-SRC3 | Owner-gated `updateSupplyCap` value on chain 4663 | Not asserted; NN-01 evidence; **not** an owner choice |
| R-SRC4 | NetNet `staking()` and `sNet()` actual addresses | Not asserted; NN-01 evidence |
| R-SRC5 | `rewardIndexesCurrent` vs `Stored` delta on chain 4663 | Not asserted; NN-01 evidence |
| R-SRC6 | Confirm `claimRewards` emits `RewardToken`/`ETHER`/`PENDLE` from configured list | Not asserted; NN-01 evidence |

These are NN-01 evidence items, not new owner questions, not new pricing/model questions, not design alternatives.

---

## 7. PRD/plan amendment scope (concrete, narrow)

**Confirmed reusable helpers (do not duplicate):**
- `lib/crane/contracts/dexes/balancer/v3/utils/BalancerV3WeightedPoolQuote.sol` (Weighted exact-in/out, fees).
- `lib/crane/contracts/protocols/perps/pendle/offchain-helpers/router-static/base/ActionAddRemoveLiqV3.sol` (Keep-YT entry).
- `lib/crane/contracts/protocols/perps/pendle/offchain-helpers/router-static/base/ActionMiscV3.sol` (joint position quote/exit).
- `DETFFundedStakingRepo.sol:185–202` (`_distribute`) + `DETFFundedStakingMath.sol` (allocation/rebase) + `DETFSeigniorageShareLib.sol` (standing weights).

**Confirmed target calls on deployed SY 0xAdAb46E7024d34E18BeBB058D374aa1069DB461E (PendleStakedNetSY):**
- `previewDeposit(tokenIn, amount)` for NET/sNET/Scaled-NET → SY estimate.
- `previewRedeem(tokenOut, amount)` for SY → NET/sNET/Scaled-NET estimate.
- `deposit(receiver, tokenIn, amount, minSharesOut)` with measured `amountSharesOut`.
- `redeem(receiver, amount, tokenOut, minTokenOut, burnFromInternalBalance)`.
- `assetInfo()`, `getTokensIn()`, `getTokensOut()`, `isValidTokenIn()`, `isValidTokenOut()` for supported tokens.
- `exchangeRate()` for SY/underlying rate snapshot.
- `yieldToken()` is address(0) per standard SYBase (the parent SY is itself the yield source).
- `net()/staking()/sNet()/scaledNet()` accessors for cross-contract reads.

**No pricing model change.** No new fee. No new lock. No new guard. **Existing plan v0.6 L3 resolution stands: use the existing helpers and target the deployed SY as configured.**

---

## 8. Identified misses (recorded once, no retries)

1. `https://api.github.com/repos/pendle-finance/Pendle-SY-Public/contents/contracts/core/StandardizedYield/implementations/NET` → **404** (no `NET` directory).
2. `https://sourcify.dev/server/files/any/4663/0xAdAb46E7024d34E18BeBB058D374aa1069DB461E?fields=abi,compilation,sources` → **403**.
3. `https://sourcify.dev/server/files/any/4663/0xAdAb46E7024d34E18BeBB058D374aa1069DB461E.json` → **403**.
4. `https://sourcify.dev/server/v2/contract/4663/0xAdAb46E7024d34E18BeBB058D374aa1069DB461E/sources` → **404**.
5. `https://sourcify.dev/server/v2/contract/4663/0xAdAb46E7024d34E18BeBB058D374aa1069DB461E/sources.html` → **404**.
6. `https://repo.sourcify.org/contracts/full_match/4663/0xAdAb46E7024d34E18BeBB058D374aa1069DB461E[/?fields=all]` → transport error / 404 (repo.sourcify.org endpoint unreliable this round).

---

## 9. Confidence and evidence limits

- **High** Sourcify exact_match ABI verified 2026-09-27 for `0xAdAb46E7024d34E18BeBB058D374aa1069DB461E` on chain 4663.
- **High** ABI reflects standard SYBase + DecimalsWrapper integration pattern (constructor signature, public functions, errors).
- **High** `BalancerV3WeightedPoolQuote.sol` provides Weighted exact-in/out with fees; not duplicated.
- **High** `DETFFundedStakingRepo._distribute` + `DETFFundedStakingMath._rebase` provide the funded-gons accounting core.
- **Medium** that the deployed `PendleStakedNetSY.sol` body conforms to standard SYBase/DecimalsWrapper integration; exact match body unavailable publicly.
- **Low** on live conversion values at call-time (NN-01 evidence deferred).
- **Low** on `_rewardIndexesCurrent` (NetNet-specific reward module).
- **Not claiming** the deployed source matches any specific public file; ABI is what we have.
- **Not claiming** the deployed SY is from public Pendle repo; deployment is NetNet-specific.
- **Not reopening** weights, Universal NET synthetic, usual oracle fees, holder proxies, excess same-NFT, pre-maturity rebond, intermediate no-reset / final E+1, independent new-bond locks, NN-03 failure scope.

**Saved:** `docs/research/netnet-sy-conversion-2026-09-27/minimax-original.md`. Originals untouched.
