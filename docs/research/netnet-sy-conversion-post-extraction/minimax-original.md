# MiniMax M3 — Independent original research, post SY source extraction

- Researcher: MiniMax M3 (independent, fresh operator-authorized pass; no peer findings or earlier cross-review consulted).
- Scope: post-extraction analysis of the verified `PendleStakedNetSY` compilation that funds selected NET/sNET routes through the SY book, in light of the PRD v0.33 + implementation plan v0.7 + PRD Open Questions v0.7 baseline.
- Source identity (from plan §6.5, accepted as fixed): SY proxy `0x5d446a2be952f4f9ba241b382a73ad3b1819aaf5`; service-resolved implementation `0xAdAb46E7024d34E18BeBB058D374aa1069DB461E`; Sourcify match `47105638`, exact_match creation/runtime, verified `2026-09-04T08:05:04Z`; compilation: `solc 0.8.30+commit.73712a01`, optimizer `1,000,000`, `viaIR=true`, Cancun. These are external compilation settings — local IndexedEx builds at solc 0.8.35 / optimizer 1 / `via_ir=false` (`foundry.toml:1–5,29–36`); no claim is made that the deployed bytecode matches a local IndexedEx rebuild.
- Access date for this pass: 2026-09-28.
- Local NetNet references used (snapshot 2026-09-24): `lib/crane/contracts/protocols/pol/net/src/Staking.sol` (161 lines), `…/Constants.sol`, `…/interfaces/IStaking.sol`, `…/interfaces/IsNET.sol` — these are reference bodies, not certified deployed equivalence.
- PRDs/plans read (not peer artefacts): `docs/strategies/ohm-style/netnet-pendle/NETNET_PENDLE_DETF_PRD.md` v0.33, `NETNET_PENDLE_DETF_IMPLEMENTATION_AND_TEST_PLAN.md` v0.7, `PRD_OPEN_QUESTIONS.md`; primary shared evidence `docs/research/netnet-sy-conversion-2026-09-27/VERIFIED_SY_SOURCE_EXTRACTS.md` (25-source decode completed 2026-09-28).
- Local helpers consulted for funding/wrap math reuse claims: `lib/crane/contracts/protocols/dexes/balancer/v3/utils/BalancerV3WeightedPoolQuote.sol:14–49`; `lib/crane/contracts/external/balancer/v3/vault/contracts/BasePoolMath.sol:50–107,126–397,277–343,359–398`; `contracts/hooks/uniswap/v4/standardExchange/weighted/UniswapV4StandardExchangeWeightedBufferHookMath.sol:16–528`.
- This is documentation. No execution, no peer reading, no shell/tests, no edits outside this file.

## 1. Bottom-line MiniMax finding

The compiled `PendleStakedNetSY` (verified public source, 25 files, round-tripped) is a **two-token (NET, sNET), internal-share-coupled SY whose arithmetic depends on `sNet.index()` mirrored at the decimals-offset boundary**. Ordinary NET/sNET output funding cannot be derived from a raw SY balance alone — it must be split into a **current NET-leg branch** (uses `_syncedIndex()` and pays out unstake) versus a **current sNET-leg branch** (uses `IStakedNet(sNet).index()` and pays a direct sNET transfer), and the boundary between them depends on whether the configured staking epoch has ended and whether the circulating supply is non-zero. Reuse of existing Weighted exact-input/exact-out helpers (and the V4 native boundary wrapper) for the **DETF pricing-coordinate layer is unchanged**; the missing piece is a **forward-and-minimality check** of the SY withdrawal target amount expressed in raw SY shares against the **eligible SY budget** (held + net-claimable), followed by a **held-first, claim-only-if-short** execution order, then a single `redeem` at the proxy with the receiver pre-validated. A literal `SY.balanceOf(holder)*previewRedeem` mapping is not source-valid: the target's `_previewRedeem` chooses `_syncedIndex()` versus `IStakedNet(sNet).index()` on the `tokenOut` branch, and only `tokenOut == net` actually exercises staking unstake (verified `PendleStakedNetSY.sol:90–102,139–145`). A new Weighted inverse or fee/gross-up is not required. L3 body inspection, not extraction, is the next step.

## 2. Branch table — supported deposit / redemption branches (native units, decimal boundaries, integer formulas)

All paths originate at the SY proxy `0x5d446a2be952f4f9ba241b382a73ad3b1819aaf5` resolving to implementation `0xAdAb...`. Entry/exit gates live in the SYBaseUpgV2 outer (`SYBaseUpgV2.sol:231–271`); the target-specific bodies live in `PendleStakedNetSY.sol:80–102,108–145`.

### 2.1 Constants, immutable bindings and decimal boundary (verified)

```text
INDEX_BASE      = 1e9                       (PendleStakedNetSY.sol:44)
DECIMALS_OFFSET = 1e9                       (:45)
INITIAL_FRAGMENTS = 5_000_000_000e9         (:48)
TOTAL_GONS = type(uint256).max - (type(uint256).max % INITIAL_FRAGMENTS)  (:49)
INDEX_GONS = INDEX_BASE * (TOTAL_GONS / INITIAL_FRAGMENTS)                (:50)
MAX_SNET_SUPPLY = type(uint128).max                                       (:51)
```

Notes:

- `yieldToken` is the **18-decimal scaled wrapper** of `sNet` (`PendleStakedNetSY.sol:61` calls `IPDecimalsWrapperFactory(_decimalsWrapperFactory).getOrCreate(_sNet, 18)`); SY ERC20 decimals therefore = 18 (PendleERC20Upg immutable set from `IERC20Metadata(_yieldToken).decimals()` — `SYBaseUpgV2.sol:211`).
- `net` and `sNet` are taken from `IStakedNet(sNet).staking()` and `IStakedNetStaking(staking).net()` (`PendleStakedNetSY.sol:63–64`). The `scaledNet` (18-decimal wrapper of NET) is constructed but is **not** the SY ERC20; it is what `assetInfo()` returns (`PendleStakedNetSY.sol:163–165`).
- `INITIAL_FRAGMENTS` mirrors StakedNET, and `INDEX_GONS` is `TOTAL_GONS / INITIAL_FRAGMENTS * INDEX_BASE = (TOTAL_GONS / INITIAL_FRAGMENTS) * 1e9 = TOTAL_GONS / INITIAL_FRAGMENTS * 1e9`. With `INITIAL_FRAGMENTS=5e18`, `TOTAL_GONS = 2^256 − (2^256 mod 5e18)`, so `TOTAL_GONS/INITIAL_FRAGMENTS ≈ 1.157e59`. `INDEX_GONS = 1e9 * 1.157e59 = 1.157e68` — the value used to invert `newSupply` back into an index at `:124`. This is the gons-per-`scaledNet` unit; it is **NOT** 1e36 (the Olympus-style gonsPerUnit in PRD §10.2). Confirmed observation; inference label: facts from the verified source.
- The wrapper implementation body (`contracts/wrappers/PDecimalsWrapper.sol` or equivalent) is **absent** from the verified compilation; only `IPDecimalsWrapperFactory.sol` is present (`VERIFIED_SY_SOURCE_EXTRACTS.md:25,389–402`). That absence is reported, not filled. Implication: the SY proxy's `scaledNet`/`yieldToken` addresses are produced by an external on-chain wrapper factory, and the SY proxy holds the resulting 18-decimal ERC20 — the SY ERC20 itself is `scaledNet(sNet)`, not raw `sNet` (`PendleStakedNetSY.sol:61,163–165`). The SY ERC20 (yieldToken) therefore **does not 1:1 mirror sNet**; its decimals are 18 by construction. NET-decimals-normalization must respect this 18-decimal SY ERC20 when computing back to native sNET/NET via `previewRedeem`.
- `PendleStakedNetSY.initialize` (`:69–74`) sets `supplyCap = type(uint256).max` (no mint cap), and approves `net` and `sNet` to `staking` with the `_safeApproveInf` allowance pattern (`TokenHelper:1459–1465`). Decimals of the input `net` and `sNet` are read by the wrapper factory; the SY itself never asserts their decimals. Inference label: fact from source + acknowledged gap.

### 2.2 Deposit branches (`PendleStakedNetSY._deposit:80–88`)

| tokenIn | Branch behavior | Forward `amountSharesOut` formula | Inverse (deposit q from shares) | Forward verification | Native unit / decimal boundary | Reverts |
|---|---|---|---|---|---|---|
| `net` | `IStakedNetStaking(staking).stake(address(this), amountDeposited)` first, then mint shares. The `stake` call **does its own rebase**: `Staking.sol:90` calls `_rebaseIfDue()` before pulling `net.transferFrom`. The SY is then a `to` recipient. If the configured Staking `warmupEpochs > 0` (constructor arg) the new stake is queued; otherwise sNET is delivered immediately (`Staking.sol:92–101`). | `floor(amountDeposited * DECIMALS_OFFSET * INDEX_BASE / IStakedNet(sNet).index())` — **uses live `IStakedNet(sNet).index()`, not `_syncedIndex()`**. | For target shares `s`, `amountDepos = ceil(s * IStakedNet(sNet).index() / (DECIMALS_OFFSET * INDEX_BASE))`. | `computeOutGivenExactIn` is not the right analogue: the formula is a single integer div in source. The V4 Weighted helper is **not** invoked here; the SY does not call Weighted at all. | `amountDeposited` is in NET native units (its own decimals — not normalized to 18 by the SY). The product is in `(DECIMALS_OFFSET * INDEX_BASE)=1e18` index units; shares are in SY ERC20 18-decimal units. They are **not** interchangeable across a decimals factor. | `SYInvalidTokenIn` if `tokenIn != net && tokenIn != sNet` (`SYBaseUpgV2.sol:237`, target override at `:155–157`). `SYZeroDeposit` if `amountDeposited == 0` (`SYBaseUpgV2.sol:238`). `NotEnabled` if Staking not yet enabled (`Staking.sol:89`). `TransferFailed` if `net.transferFrom` returns false (`Staking.sol:91`). `ThirdPartyWarmup` if a contract stakes into a non-self address while warmup > 0 (`Staking.sol:97`). |
| `sNet` | No external stake call. Just mint. | `floor(amountDeposited * DECIMALS_OFFSET * INDEX_BASE / IStakedNet(sNet).index())` — **same formula** as `net` branch. | Same as `net` branch. | Same as `net` branch. | `amountDeposited` is in sNET native units; index is dimensionless with `INDEX_BASE = 1e9` so the resulting shares are dimensionless 18-decimal. | Same as above, except `NotEnabled`/`TransferFailed` not triggered (no staking interaction). |

Observation: the SY deposit for both `net` and `sNet` collapses to **one arithmetic** that divides by `IStakedNet(sNet).index()`. It does **not** call `_syncedIndex()` — deposits cannot pre-realize the next epoch's queued profit. This is consistent with the preview path (`_previewDeposit:131–137`), which chooses `_syncedIndex()` only for `tokenIn == net` and `IStakedNet(sNet).index()` for `sNet`. The execution path (`_deposit`) however uses **only `IStakedNet(sNet).index()`** regardless of tokenIn — this is a one-character drift between preview and execution worth flagging in §6.5. Confirmed observation; inference label: facts + a noted inconsistency between the two adjacent bodies in the same file (not an interpretation).

### 2.3 Redemption branches (`PendleStakedNetSY._redeem:90–102`)

| tokenOut | Branch behavior | Forward `amountTokenOut` formula | Inverse (redemption q from required tokenOut) | Forward verification | Native unit / decimal boundary | Reverts |
|---|---|---|---|---|---|---|
| `net` | Reads `_syncedIndex()` (with epoch-advance simulation if the current epoch ended and `queuedProfit>0`), then computes the raw NET to unstake, then `IStakedNetStaking(staking).unstake(receiver, amountTokenOut)`. The `unstake` itself does a `_rebaseIfDue()` first (`Staking.sol:121`). | `floor(amountSharesToRedeem * _syncedIndex() / (DECIMALS_OFFSET * INDEX_BASE))`. The receiver receives NET in raw NET units. | For required raw `amountTokenOut`, `amountSharesToRedeem = ceil(amountTokenOut * DECIMALS_OFFSET * INDEX_BASE / _syncedIndex())`. Bound on `_syncedIndex()`: `1e9 ≤ _syncedIndex() ≤ INDEX_GONS / (TOTAL_GONS / MAX_SNET_SUPPLY)` at the cap. The minimum index follows from `newSupply ≤ MAX_SNET_SUPPLY` ceiling at `:122–123`. | The forward formula uses native `net` units in `amountTokenOut`; shares are 18-decimal. The product `shares * _syncedIndex()` is in 18+9 = 27 decimal magnitude (since `_syncedIndex()` has 9-decimal semantics), and `DECIMALS_OFFSET * INDEX_BASE = 1e18`, so `amountTokenOut` is in raw 9-decimal NET. Division by `1e18` recovers 9 decimals. | `SYInvalidTokenOut` if `tokenOut != net && tokenOut != sNet` (target override at `:159–161`). `SYZeroRedeem` if `amountSharesToRedeem == 0` (`SYBaseUpgV2.sol:260`). `SYInsufficientTokenOut` if `amountTokenOut < minTokenOut` (`SYBaseUpgV2.sol:269`). `TransferFailed` from `net.transfer` to receiver in `unstake` (`Staking.sol:123`). The `MAX_SNET_SUPPLY` cap in `_syncedIndex()` reduces the effective index when new supply exceeds `type(uint128).max`; this is a real ceiling that influences funding capacity. |
| `sNet` | `amountTokenOut = floor(amountSharesToRedeem * IStakedNet(sNet).index() / (DECIMALS_OFFSET * INDEX_BASE))`, then `_transferOut(sNet, receiver, amountTokenOut)`. | Same formula but with `IStakedNet(sNet).index()`. | For required `amountTokenOut`, `amountSharesToRedeem = ceil(amountTokenOut * DECIMALS_OFFSET * INDEX_BASE / IStakedNet(sNet).index())`. | Same as `net` branch but uses **current** index, not projected. | `SYInsufficientTokenOut` if `amountTokenOut < minTokenOut` (`SYBaseUpgV2.sol:269`). `_transferOut` revert (`TokenHelper:1423–1431`) on failure. |

Critical observation: the `net` redemption branch routes through `unstake`, which calls `sNet.transferFrom(msg.sender, address(this), amount)` then `net.transfer(to, amount)` — `Staking.sol:119–126`. The receiver must already have **transferred shares** into the staking contract, or this reverts. For hook-driven redemptions, the SY proxy holds its own shares (it is the depositor of record via `_deposit`), so the standard `burnFromInternalBalance = true` path (`SYBaseUpgV2.sol:262–266`) is the supported route. **Internal-balance redemption is the hook's normal path**: the SY proxy calls `_burn(address(this), amountSharesToRedeem)` and then unstakes on behalf of `receiver`, paying raw NET to the caller. Fact from source.

### 2.4 `exchangeRate()` and pricingInfo

```text
exchangeRate() = _syncedIndex() * DECIMALS_OFFSET     (PendleStakedNetSY.sol:108–111)
pricingInfo()   = (sNet, false)                       (PendleStakedNetSY.sol:167–169)
```

For sNET-coordinated rate providers, the reusable per-SY rate derivation per PRD §4.5 is `floor(a * 10^syDecimals * 1e18 / (q * 10^targetDecimals))` using `previewRedeem(sNet, q)` and `q`. Here `syDecimals = 18`, `targetDecimals = sNet.decimals()`. The SY ERC20 is `scaledNet(sNet)`, not raw `sNet`; the provider must publish the **per-share rate to sNET** (not raw 9-decimal sNET, unless explicitly mapped). The PRD's note that `exchangeRate()` "is usable directly only with verified denomination/decimal/conversion semantics" is borne out by this code: `exchangeRate()` is `index * 1e9`; only an `sNet`-aware downstream caller knows that the units are `(scaledNet per rawNet)` (since index is dimensionless with `INDEX_BASE=1e9` and sNet is rebasing gons-on-shares). Confirmed observation.

### 2.5 Token lists and validity

`getTokensIn`/`getTokensOut` return `[net, sNet]` (`PendleStakedNetSY.sol:147–153`). `isValidTokenIn`/`isValidTokenOut` accept `net` or `sNet` (`:155–161`). The SY ERC20 itself (the 18-decimal scaled wrapper of sNet) is **not in `getTokensOut`/`getTokensIn`** — the user cannot deposit the SY ERC20 to mint itself. Confirmed fact.

### 2.6 Supply cap (initialized to `type(uint256).max`)

`_checkSupplyCap(totalSupply())` is called only on mint-to-non-zero (`:179–184`). The initial cap is `type(uint256).max` (`initialize:71`), so the cap does not constrain the SY total supply today. The `MAX_SNET_SUPPLY = type(uint128).max` ceiling in `_syncedIndex` (`:122–123`) **does** clamp the projected new supply, hence the effective index. Inference label: fact from source.

## 3. `_syncedIndex()` and the (projected vs current) index floor

```solidity
function _syncedIndex() internal view returns (uint256) {
    (, , uint64 epochEnd, uint256 queuedProfit) = IStakedNetStaking(staking).epoch();
    uint256 currentIndex = IStakedNet(sNet).index();
    if (block.timestamp < epochEnd || queuedProfit == 0) return currentIndex;
    uint256 supply = IStakedNet(sNet).totalSupply();
    uint256 circulating = supply - IStakedNet(sNet).balanceOf(staking);
    if (circulating == 0) return currentIndex;
    uint256 newSupply = supply + (queuedProfit * supply) / circulating;
    if (newSupply > MAX_SNET_SUPPLY) newSupply = MAX_SNET_SUPPLY;
    return INDEX_GONS / (TOTAL_GONS / newSupply);
}
```

Exact branches and floors:

1. If `block.timestamp < epochEnd` **or** `queuedProfit == 0`, return `currentIndex()` unchanged (no advance).
2. If `epoch` ended but `queuedProfit == 0`, also `currentIndex` (no profit to distribute; **`newSupply` could even underflow conceptually but the code short-circuits**).
3. If `circulating == 0`, return `currentIndex()` (the queued profit cannot be distributed when everyone has unstaked; this is a hard `if`, not a zero-divide branch).
4. Otherwise `newSupply = supply + (queuedProfit * supply) / circulating`, with `MAX_SNET_SUPPLY = type(uint128).max` clamping.
5. Return `INDEX_GONS / (TOTAL_GONS / newSupply)` — integer division, **floor**. (EVM `/` floors toward zero.)

Subtleties to record for the plan:

- **Floor at `INDEX_GONS / (TOTAL_GONS / newSupply)`**: if `TOTAL_GONS / newSupply` is not a divisor of `INDEX_GONS`, the projected index is rounded **down** — favoring the protocol/treasury on redemption. The matching forward formula `_syncedIndex()` for the `net` redemption branch therefore **systematically underestimates NET output versus the post-rebase index**. The caller (hook) cannot claim more than this floor.
- **Zero circulating short-circuit**: at the `if (circulating == 0) return currentIndex;` branch, the queued profit is not distributed and the index does not advance. This is *not* a guaranteed pending-epoch catch-up — it is a documented contract branch.
- **MAX_SNET_SUPPLY cap**: when the projected new supply exceeds `type(uint128).max`, the index is computed against the capped supply, which floors the projected index.
- **Time-deferred distribution**: `_syncedIndex()` is a **view function** that simulates the next epoch's rebase; the actual `sNet.rebase()` and index update happen **inside** `IStakedNetStaking(staking).stake` / `unstake` via `_rebaseIfDue()` (`Staking.sol:90,121,134–151`). The redemption caller (hook) **does not** need to call `rebase()` separately to get the post-rebase index; each call to `_redeem(net)` will eventually call `unstake` which calls `_rebaseIfDue()` first, but the **quote path** uses `_syncedIndex()` to simulate it earlier. There is therefore an index used-for-quote and an index used-for-actual — both are identical only because `_syncedIndex()` mirrors the `_rebaseIfDue()` formula exactly: `newSupply = supply + (queuedProfit * supply) / circulating` and `sNet.rebase(distributed, _epoch.number)` (`Staking.sol:138–142`) does `sNet.index = INDEX_GONS / (TOTAL_GONS / newSupply)` via the StakedNET gons math (mirror, not verified here). Inference label: fact for the SY view + reference-level confidence that Staking.rebase flow is the underlying update.

**Implication for §6.5**: the hook's quote must compute forward output using `_syncedIndex()` (not `IStakedNet(sNet).index()`) whenever the target is `net`. The same call, made after `unstake` consumed a rebase, will see `block.timestamp < newEpochEnd` and use the now-`currentIndex()`. There is **no need** for the hook to call `rebase()` itself — the SY enforces this through `unstake` on the NET branch. For the `sNet` branch, only the live `IStakedNet(sNet).index()` is used.

## 4. Stake/unstake/rebase ordering, overdue-epoch advancement, and the one-epoch-per-call rule

Local NetNet `Staking.sol:128–151`:

- `_rebaseIfDue()` (`:134–151`) advances **at most one epoch per call**: `if (block.timestamp < _epoch.end) return;` then `_epoch.end += _epoch.length; _epoch.number += 1;`.
- The sNET rebase calls `sNet.rebase(distributed, _epoch.number)`. If `circulating == 0`, the `_epoch.distribute` is **not** zeroed in the local code path (a careful read of `:138–144`: when `circulating == 0`, `distributed = 0` is initialized and the `sNet.rebase(distributed, _epoch.number)` is **still called** with `distributed=0` — this is a rebase with no new sNET supply but still bumps `_epoch.number` and `_epoch.end` and resets `_epoch.distribute = 0` only inside the `if (circulating > 0)` branch. Wait — read again: `_epoch.distribute = 0;` at line 143 is inside the `if (circulating > 0)` block. If `circulating == 0`, `_epoch.distribute` is **not** zeroed and `_epoch.distribute += distributor.distribute();` is then executed (line 150). So queued profit **rolls forward** until stakers return. Implication for funding: `_syncedIndex()` short-circuit on `queuedProfit == 0` does **not** clear the queue; the queue survives across zero-circulating epochs. Confirmed observation from local source; uncertain whether Staking on chain behaves identically (the implementation agent's constants update record did not address this difference).
- Back-to-back calls advance **multiple epochs**: each call increments `_epoch.number` by 1, but only when `block.timestamp >= _epoch.end`. The PRD R25 / plan §8.2 mandate **no per-epoch loop** at the DETF layer; the single-call one-epoch advancement at the staking layer is acceptable, and the DETF's aggregate `floor(S0*n/200)` formula does not depend on per-epoch processing.
- The plan also states that the DETF's "completed processed NET epochs not yet consumed" comes from a single staking query (plan §8.2). Combining this with the `_rebaseIfDue` one-epoch-per-call rule: the hook does **not** call `rebase()` itself to consume pending epochs. It only reads `IStakedNetStaking(staking).epoch()` and the cached `_epoch.number` advanced by external callers (any user calling `rebase()`). This is consistent with the v0.31 funded-gons switch: DETF expansion uses `floor(S0*n/200)` over **unconsumed** epochs; the consumption event is the DETF's own bookkeeping, not a stake/unstake. Confirmed observation; inference label: fact + plan-rule consistency.

**Per-call epoch advancement by a hook-side caller**: The SY's `_redeem(net)` path calls `unstake`, which calls `_rebaseIfDue()`, which advances at most one epoch. So **a single redemption cannot skip multiple pending epochs through the SY**. If the hook chooses to advance multiple epochs before quotation, it would have to call `rebase()` itself on the staking contract, then call `_redeem`. Whether that is desired depends on quote/execute parity. The PRD R52 says "no replay, cap, premium multiplier or new clock" but it does not forbid a single `rebase()` kick before expansion settlement to materialize the index used by `_syncedIndex()` for that settlement. Recommendation is to call `rebase()` exactly once (or `n` times if `block.timestamp >= epochEnd + n*epochLength`) before expansion. This is engineering design, not a PRD instruction; absent explicit PRD text it must remain engineering work. Inference label: engineering recommendation, not a source fact.

## 5. Fixed-state inverses and forward/minimality checks

For the SY legs:

```text
forward (deposit net):     shares = floor(N * DECIMALS_OFFSET * INDEX_BASE / IStakedNet(sNet).index())
inverse (deposit shares):  N      = ceil(shares * IStakedNet(sNet).index() / (DECIMALS_OFFSET * INDEX_BASE))

forward (deposit sNet):    same as net branch (uses IStakedNet(sNet).index())
inverse (deposit sNet):    same formula

forward (redeem net):      tokenOut = floor(shares * _syncedIndex() / (DECIMALS_OFFSET * INDEX_BASE))
inverse (redeem net):      shares   = ceil(tokenOut * DECIMALS_OFFSET * INDEX_BASE / _syncedIndex())

forward (redeem sNet):     tokenOut = floor(shares * IStakedNet(sNet).index() / (DECIMALS_OFFSET * INDEX_BASE))
inverse (redeem sNet):     shares   = ceil(tokenOut * DECIMALS_OFFSET * INDEX_BASE / IStakedNet(sNet).index())
```

**Minimality checks**:

- The forward formula is an integer division (floor). The minimal inverse that *guarantees* the forward result is a ceil-div: `ceil(required * 1e18 / index)` (using `DECIMALS_OFFSET * INDEX_BASE = 1e18`). For the `net` redemption branch, `required` is the raw NET amount the user wants.
- For `_syncedIndex()` projection, the forward formula also floors `INDEX_GONS / (TOTAL_GONS / newSupply)`. This is **not** an exact algebraic inverse — `TOTAL_GONS / newSupply` is itself an integer floor. The matching inverse is therefore an *upper bound*, not an exact reconstruction. Consequence: a single-share `sh = 1` redemption on the net branch can return `0` NET output if `_syncedIndex() < 1e18`. A minimality test must assert `forward(inverse(x)) ≥ x` and `forward(inverse(x) − 1) < x` (strict floor).
- Checked-arithmetic domain: every forward formula does a single multiplication followed by an integer division. The product `shares * _syncedIndex()` is in `(2^256 - 1)^2 ≈ 2^512` raw — Solidity 0.8.x checked multiplication **reverts** on overflow. The fixed-state inverse for `_syncedIndex()` near `MAX_SNET_SUPPLY` can grow above `INDEX_BASE` (the index rises as supply rises per the gons mirror), but is bounded by `INDEX_GONS` for supply approaching the sNET gons floor (initial supply `5e18`). Specifically:
  - `INDEX_GONS = INDEX_BASE * (TOTAL_GONS / INITIAL_FRAGMENTS) ≈ 1e9 * 1.157e59 = 1.157e68`; well below `2^256 ≈ 1.16e77`. So `INDEX_GONS` fits in uint256.
  - `TOTAL_GONS / newSupply` for any `newSupply ≥ INITIAL_FRAGMENTS` is at most `(2^256 - 1)/5e18 ≈ 1.157e59`, fits in uint256.
  - The product `shares * _syncedIndex()` for `shares ≤ SY.totalSupply()` and `_syncedIndex() ≤ INDEX_GONS` is bounded by `SY.totalSupply() * INDEX_GONS`. If `SY.totalSupply()` is itself capped only by `_supplyCap = type(uint256).max`, then the product can exceed `2^256` and revert. **The supply cap effectively prevents this for realistic supply** (since `_supplyCap = uint256.max` and `SY.totalSupply()` is a uint248 in the storage — `PendleERC20Upg.sol:687` — `totalSupply()` is bounded by `2^248 - 1`). The product is therefore bounded by `(2^248 - 1) * 1.157e68 ≈ 2^312` — **this overflows uint256** and the multiplication reverts. This is a real checked-arithmetic domain issue.
- Mitigation in the SY source: the source uses **plain solidity `*`** (`PendleStakedNetSY.sol:87,96,99,136,144`) — checked. There is no `unchecked` block. The SY therefore can revert on a `redeem` whose product overflows uint256. The hook must apply checked arithmetic in the same domain. Plan §6.4 already states the SY conversion is the L3 deliverable; this overflow domain is a noted risk.

**Minimum-output guards**: `SYBaseUpgV2.redeem:269` requires `amountTokenOut >= minTokenOut` and reverts with `SYInsufficientTokenOut`. This is the source's actual minOut guarantee. The hook must set `minTokenOut` to the user-supplied minimum, not bypass it. Forward verification: at the same projected state, `forward(inverse(x)) ≥ x` — for `minTokenOut = x` we need `ceil(x * 1e18 / _syncedIndex()) * _syncedIndex() / 1e18 ≥ x`. This holds by construction. Confirmed fact from source.

## 6. Caller / internal-share custody, pulls, transfers, minOut, receipt measurement

### 6.1 SY ERC20 shares and `burnFromInternalBalance`

- `SYBaseUpgV2.deposit:240–246` calls `_transferIn(tokenIn, msg.sender, amountTokenToDeposit)` (`TokenHelper:1414–1417`) and `_mint(receiver, amountSharesOut)`. The SY proxy itself becomes a share holder when the hook (or anyone) deposits.
- `SYBaseUpgV2.redeem:262–266` supports `burnFromInternalBalance = true` to burn shares held by `address(this)` (the SY proxy). For the hook's ordinary NET/sNET output, the SY proxy holds its own shares (deposited earlier as part of Keep-YT input accounting — `PendleStakedNetSY._deposit` does **not** itself move shares to anyone; the `_mint(receiver, amountSharesOut)` at the outer layer credits the SY proxy). Wait — re-read: `_mint(receiver, amountSharesOut)` (`SYBaseUpgV2.deposit:245`) credits `receiver` (the original deposit caller). So if the hook calls `deposit`, the SY proxy does **not** automatically hold the shares — they go to `msg.sender` (the hook), not the SY. Therefore for an ordinary-output funding path the SY proxy does **not** hold the redeemed shares by default. The hook would need to pre-deposit and pre-burn via `burnFromInternalBalance = true`. Inference label: read-through of the source; the hook author must decide whether the SY is the receiver or whether the SY is called from a hook-owned sub-account.

  **Two valid hook designs** (engineering choice):
  1. **Receiver = SY proxy**: hook calls `deposit(receiver=SY, ...)` so the SY proxy ends up holding the shares it would later redeem internally. Then ordinary output can use `redeem(receiver=user, shares, tokenOut, minOut, burnFromInternalBalance=true)`.
  2. **Receiver = hook itself**: hook holds shares, then explicitly transfers them to SY before calling `redeem`. This is a needless extra step in the common case.

  Plan §6.5 / §6.4 should specify option 1 as the default, with the SY proxy as the canonical `receiver` for the hook-funded Keep-YT path.

- The SY ERC20 (`PendleERC20Upg`) is `nonReentrant` on `transfer` and `transferFrom` (`PendleERC20Upg.sol:703–715,779–783,824–833`), blocks self-transfers (`PendleERC20Upg.sol:852`), and disallows reentrancy. The `deposit` and `redeem` are themselves `nonReentrant`. So **the hook must never call `SY.deposit` then `SY.redeem` from the same call site in a single user-tx if there is a reentrancy concern**; the SY itself prevents this for direct calls.

### 6.2 `minOut` measurement and actual receipt

- `SYBaseUpgV2.redeem:269` checks `amountTokenOut >= minTokenOut` *before* the external call (`unstake` or `_transferOut`). **The source's check is on the computed amount, not on the actual transferred balance.** For the `net` branch, `unstake` calls `net.transfer(to, amount)`; a token that returns success without actually transferring — i.e., a non-ERC20-compliant or rebasing-underlying token — would pass the SY's check but fail to deliver NET. The hook must therefore either trust the SY's `amountTokenOut` as the receipt (it equals `net.transfer` amount by source), or wrap it in its own balance-delta measurement. The PRD §6.1/§6.2 requires actual receipt measurement; the SY source itself does not perform a balance-delta check after `unstake`. Inference label: noted gap.
- The hook's measurement should be: `received = net.balanceOf(receiver)` before/after; reconcile with `amountTokenOut`. If `received < amountTokenOut`, the operation must revert (the PRD §6.2 reverts on failure). For the `sNet` branch, the same logic applies to `sNet.balanceOf(receiver)`.

### 6.3 Events

`SYBaseUpgV2.deposit:246` emits `Deposit(caller, receiver, tokenIn, amountDeposited, amountSyOut)`; `redeem:270` emits `Redeem(caller, receiver, tokenOut, amountSyToRedeem, amountTokenOut)`. These are the only `amountSyOut`/`amountTokenOut` receipts. Plan §5.6 must include `Redeem` as a retained event. Confirmed fact.

## 7. Held-first, claim-only-if-short, recompute, rollback

This is the plan §6.4 §6.5 integration requirement, not a single SY function. With the verified SY body:

1. **Quote** the requested NET or sNET output amount `outNative` using the **DETF pricing-coordinate Weighted helpers** (`BalancerV3WeightedPoolQuote.computeOutGivenExactInAfterFee` or V4 `quoteExactIn/Out`), at the configured weights, on a coherent pre-quote reserve snapshot. The Weighted helper returns `outNative` in **NET or sNet native units**, not in raw SY shares. Confirmed fact: the Weighted helper does not know about SY.
2. **Convert** `outNative` to **required raw SY shares** using the inverse in §5 above:
   - NET branch: `reqShares = ceil(outNative * DECIMALS_OFFSET * INDEX_BASE / _syncedIndex())`.
   - sNet branch: `reqShares = ceil(outNative * DECIMALS_OFFSET * INDEX_BASE / IStakedNet(sNet).index())`.
3. **Compute the eligible SY budget** as `E = heldRaw + netClaimableRaw`, where:
   - `heldRaw = IERC20(SY).balanceOf(hook)` minus `booked` reserves already accounted (PRD §6.3 / plan §6.1 §6.4).
   - `netClaimableRaw` is whatever the hook accrues as a Pendle-side claimable receivable; the SY itself does not expose a "claim interest" path because the SY's `claimRewards`/`getRewardTokens`/`accruedRewards` are **all stub returns of empty arrays** (`SYBaseUpgV2.sol:309–333`).
   - Therefore, **the entire claimable layer is upstream of the SY**, not a function on the SY. The plan §6.2 step 3 ("If held SY is insufficient, collect available pending Pendle interest/rewards for the hook") cannot be performed on the SY; it must be performed on the **YT** address (Pendle side, not in this compilation). The SY compilation does not provide a claim path.
4. **Decide funding**:
   - If `E >= reqShares`: spend `reqShares` from `held` first (no claim needed). Else, attempt to claim the net receivable (outside SY); recompute `E'`; if `E' >= reqShares`, proceed; else revert the operation atomically.
5. **Redeem** via `SY.redeem(receiver=user, amountSharesToRedeem=reqShares, tokenOut=net|sNet, minTokenOut=userSuppliedMin, burnFromInternalBalance=true)`. The SY burns hook-held shares (the SY proxy holds them), computes `amountTokenOut`, enforces `>= minTokenOut`, and:
   - For `net`: invokes `IStakedNetStaking(staking).unstake(receiver, amountTokenOut)`. Note that `unstake` will trigger `_rebaseIfDue()` and possibly burn `MAX_SNET_SUPPLY`-capped index. If the actual `_syncedIndex()` at execution time differs from quote time (e.g., another actor drained circulating supply), the actual output can be **less** than the quoted `minTokenOut` and the SY reverts with `SYInsufficientTokenOut`. This is the source's atomic failure mode.
   - For `sNet`: invokes `_transferOut(sNet, receiver, amountTokenOut)`. Atomic failure here is `_transferOut` revert only.
6. **State recompute** after a successful redemption:
   - Deduct `reqShares` from the SY book.
   - Add `amountTokenOut` (raw NET or sNet) to the hook's custody of the requested token.
   - **Do not** deduct a PLP/YT virtual decrement (PRD §6.1: "input acquisition, rates and time can" change the NET valuation; a single SY-output debit does not require a PLP/YT decrement unless input changed).
   - Reconcile `BasicVaultRepo` (§6.3) for the affected tokens.
7. **Rollback**: any failure in steps 3–6 reverts the entire user operation (PRD §6.2 step 5). The SY source's own revert points do not leave the SY ERC20 in a partially-burnt state because the burn (`_burn`) precedes the unstake/transfer; if the unstake reverts, the burn has already happened and the SY ERC20 lost shares without delivering output. **This is a real on-chain failure mode**: a redeem attempt whose `unstake` reverts (e.g., due to a downstream token revert in `net.transfer`) leaves the SY ERC20 burnt but the user unpaid. The hook must therefore **measure actual receipt and revert the whole user operation atomically**, which means the hook must wrap the SY call and absorb the burn if the unstake fails — this is the **rollback** responsibility the PRD §6.2 §5 demands. Plan §6.5 must specify this guard. Inference label: fact + engineering recommendation.
8. **Positive native SY remainder**: the hook must verify after a successful redeem that the SY book still has a positive raw SY remainder if there are other claimable receivables or future obligations. The PRD §6.1 prohibits full drainage. Plan §6.4 should encode this as `if (heldRaw − reqShares == 0) revert("positive remainder required")` unless the redeem path is the legitimate final-exit one. Inference label: engineering rule consistent with PRD §6.1.

## 8. Finite branch-specific source/state dependencies

| Branch | Required source reads | Required state dependencies | Reverts that bypass `minTokenOut` |
|---|---|---|---|
| Quote (`_previewDeposit`/`_previewRedeem`) | `IStakedNet(sNet).index()`; `IStakedNetStaking(staking).epoch()` for `_syncedIndex()`. | Pending NET epoch state (read-only). | None — pure view. |
| Deposit (`_deposit`) | `IStakedNet(sNet).index()`. | `staking` must be `enabled`; `net.transferFrom(msg.sender, SY)` must succeed (for `net` branch). | `NotEnabled`, `TransferFailed`. |
| Redeem-net (`_redeem`) | `_syncedIndex()`; `IStakedNet(sNet).totalSupply()`; `IStakedNet(sNet).balanceOf(staking)`; `IStakedNetStaking(staking).epoch()`. | `SY.totalSupply ≥ amountSharesToRedeem`; `sNet` (held by SY) ≥ `amountTokenOut` only if `sNet.transferFrom` is invoked — but the **net** branch uses `unstake`, which mints NET from the staking contract, not from any held sNET. | `NotEnabled`, `TransferFailed` from `sNet.transferFrom(SY, staking, amount)` and `net.transfer(receiver, amount)`. |
| Redeem-sNet (`_redeem`) | `IStakedNet(sNet).index()`. | `SY` holds at least `amountTokenOut` of raw sNET. | `_transferOut` revert if `sNet.balanceOf(SY) < amountTokenOut`. |
| Supply cap | `_supplyCap = type(uint256).max` (set at initialize). | None in practice today; future `updateSupplyCap` could revert mints. | `SupplyCapExceeded`. |

`getTokensIn`/`getTokensOut`/`isValidTokenIn`/`isValidTokenOut` are pure views; `pricingInfo`, `assetInfo` are pure views; `paused` is an inherited OZ Pausable gate on `_beforeTokenTransfer` (`SYBaseUpgV2.sol:363`) — a paused SY blocks transfers, mints, burns.

## 9. Required changes to plan §6.5 (post-extraction)

Concrete edits to `NETNET_PENDLE_DETF_IMPLEMENTATION_AND_TEST_PLAN.md` §6.5 (lines 421–451 of v0.7), each tied to a verified-source line range above:

1. **Replace** the line "Constructor binding to a scaled wrapper does not establish `SY shares = native sNET*1e9`; mirrored index/rebase logic must be inspected." with a concrete description:
   - SY ERC20 decimals = 18 (from `scaledNet(sNet)` constructed by `IPDecimalsWrapperFactory.getOrCreate(sNet, 18)` at `:61`).
   - SY ERC20 is the 18-decimal scaled wrapper of sNet, **not** raw sNet.
   - `exchangeRate() = index * 1e9` (i.e., raw NET per SY share, scaled at 1e9 — dimensionless index with `INDEX_BASE=1e9`).
   - Deposit and redeem formulas use `* DECIMALS_OFFSET * INDEX_BASE / index`, where the index is `IStakedNet(sNet).index()` for `sNet` deposit/redeem and `_syncedIndex()` for the `net` redeem branch.

2. **Specify** that the SY proxy must be the **canonical `receiver`** of the hook's Keep-YT `SY.deposit` calls so the SY proxy holds the shares to be redeemed internally with `burnFromInternalBalance=true`. Specify that the hook must approve `sNet` transfer to the SY proxy for any path where `burnFromInternalBalance=true` requires pre-positioned shares (it does not for direct internal burn — `SYBaseUpgV2.sol:262–263` burns `address(this)` shares directly). Plan §6.5 must explicitly enumerate the share custody flow.

3. **Specify** that `_syncedIndex()` is **view-only and not stateful**; the actual index update happens via `Staking._rebaseIfDue()` invoked inside `stake` / `unstake`. The hook must call `IStakedNetStaking(staking).rebase()` at most once before any quote that uses `_syncedIndex()` if the DETF expansion must operate on the post-rebase index; otherwise expansion may use a stale index. This is an engineering recommendation, not a PRD instruction. Note: `MAX_SNET_SUPPLY = type(uint128).max` is a hard ceiling on the projected new supply; if the queued profit overflows the cap, the index is computed against the capped supply (floor).

5. **Specify** the **checked-arithmetic domain** for forward and inverse formulas: `_syncedIndex() * shares` is bounded by `INDEX_GONS * (2^248 - 1) ≈ 2^312`; this **overflows uint256** for sufficiently large share inputs. The hook must either guard share inputs to fit within the checked-arithmetic domain or use a checked-saturating inverse that limits `reqShares` to `(2^256 - 1) / _syncedIndex()` and reverts on overflow. Solidity 0.8.x checked multiplication reverts on overflow. Plan §6.4/§6.5 must specify this domain check.

6. **Specify** that the SY source's `minTokenOut` enforcement is **pre-transfer**, not post-balance-delta: the hook must do its own balance-delta measurement after the SY returns and revert the whole operation if `received < required`. This is the PRD §6.2 §5 atomic-failure requirement.

7. **Specify** that the SY source's **net branch's unstake can revert after the share burn has already executed**. The hook must therefore wrap the SY call in its own state snapshot and revert the entire user operation (including any prior debit) if the unstake reverts. This is the documented SY-source behavior, not a hypothetical. PRD §6.2 §5 covers it, but the SY-level mechanism (burn before unstake) is verified.

8. **Specify** that `SYBaseUpgV2` stubs `claimRewards/getRewardTokens/accruedRewards/rewardIndexesCurrent/rewardIndexesStored` as empty arrays (`SYBaseUpgV2.sol:309–333`). The "claim if short" funding path **cannot** use the SY; it must use the **Pendle YT** address (verified outside this compilation). The PRD §6.2 step 3 references interest collection "for the hook"; that collection is at the YT layer, not the SY layer. Plan §6.5 must correct the language that conflates "SY claim" with "YT interest claim".

9. **Specify** that `MAX_SNET_SUPPLY = type(uint128).max` is a real ceiling that may cap the effective index; the hook must not assume `_syncedIndex()` grows unboundedly with queued profit. The cap means large queued profit results in a lower realized index than the unscaled projection.

10. **Specify** the inconsistency between `_deposit` (always uses `IStakedNet(sNet).index()`) and `_previewDeposit` (uses `_syncedIndex()` for `tokenIn == net`, `IStakedNet(sNet).index()` otherwise). For deposits this is a 0-or-1 index divergence when the epoch has ended and `queuedProfit > 0`. The hook's preview/execute parity tests must cover this divergence and document whether the protocol accepts the divergence (the on-chain execution always uses `IStakedNet(sNet).index()` for both branches; preview can over-estimate deposit shares for the `net` branch). Inference label: noted inconsistency in source.

11. **No** new weighted inverse or fee decision is required (confirmed consistent with plan §6.4 / PRD §4.3): the SY is a linear index-based conversion, not a Weighted swap; the Weighted pool math lives at the HLP layer, separate from the SY legs. The plan's "no new Weighted inverse" claim is correct.

12. The plan §6.5 **does not** claim to have inspected `_deposit`, `_redeem`, preview, exchange-rate, token-list and due-epoch/index bodies; that is precisely the L3 work this round addresses. Once the inspection is recorded (this document), L3 body inspection is closed by §2–§8 above; L3 is **not** closed for source-mapping of the *internal-share bookkeeping*, which remains engineering work for plan §6.5 + W12. The wrapper implementation is absent from the compilation (verified); SY ERC20 decimals = 18 is established.

## 10. Unchanged PRD economics, preserved invariants

- Weighted helper/native fee order: not modified. SY is not a Weighted pool.
- No new reserve model: not introduced. The "shared ordinary SY budget held first" rule lives at PRD §6.2 step 2 (plan §6.4) and is unchanged.
- No double fee: not introduced. SY has no fee in the verified source. The "first call to fee gross-up" rule (PRD §4.3) is unchanged.
- Shared ordinary SY budget held first, claim only if short: enforced by §7 of this document. The "claim" half is at the YT layer, not the SY.
- No ordinary PLP/YT liquidation: confirmed. `_redeem` does not interact with PLP/YT. `positionToSy`/`exitPostExpToSy`/`exitPreExpToSy` are not invoked.
- No percent reserve floor: not introduced. The "positive remainder" rule is a binary check, not a percent.
- Owned-HLP BasePoolMath modes: unchanged. The Weighted layer still uses `BalancerV3WeightedPoolQuote` and `UniswapV4StandardExchangeWeightedBufferHookMath`; SY is upstream of those, not a substitute.
- L1 funded-gons/notification: not modified. L1 is the staking child (PRD §10.2 / plan §9), distinct from the SY.
- L2 origin-independent public surplus credit: not modified. L2 is the public pretransfer rule (PRD §6.3 / plan §6.1), distinct from the SY.
- NN-03 closed: still closed. The "broken SY balance interface" failure mode is not in scope of the SY source; the SY returns standard ERC20 `balanceOf`. A paused SY blocks transfers (`SYBaseUpgV2.sol:363`); this is **not** a break in the sense of NN-03.
- L4 terminal late-proceeds: not modified. L4 lives at the NFT/holder layer (PRD §12.4), distinct from the SY.
- G0/G1 distinct: G0 is maintainer reconciliation; G1 is dependency/source evidence. The SY compilation is a G1 evidence item; G0 is unchanged. The plan §2.1 G1 row already references this source.

## 11. Counterarguments

- **Counterargument A (executable preview parity is impossible for the `net` deposit branch)**. The `_deposit(net)` body uses `IStakedNet(sNet).index()` (`:87`), but `_previewDeposit(net)` uses `_syncedIndex()` (`:135`). When `block.timestamp ≥ epochEnd && queuedProfit > 0 && circulating > 0`, the preview over-estimates shares by `factor = _syncedIndex() / IStakedNet(sNet).index() > 1`. A pre-deposit call to `previewDeposit` therefore reports a higher share count than the actual `_deposit` mint. MiniMax M3 considers this **a real preview/execute parity bug in the deployed SY source**, not a misinterpretation. Mitigation: the hook must read the actual `_deposit`-time index, not the preview; the source itself does not patch this. This was previously attributed as "preview is best-effort" (PRD §4.5); the verified source confirms it concretely. **The PRD/plan language "preview is best-effort" must not be used to silently accept a routine under-mint for the `net` deposit branch.** Plan §6.5 must either call `rebase()` before `previewDeposit(net, …)` to align the index, or apply the inverse correction `actual = preview * IStakedNet(sNet).index() / _syncedIndex()` (floor). Confirmed fact.

- **Counterargument B (the `sNet` redemption branch does not include the queued profit)**. `_redeem(sNet)` uses `IStakedNet(sNet).index()`, not `_syncedIndex()` (`:99`). For a redemption of a hook-held share position that just exited an epoch, the **SY redemption sNet output uses the pre-rebase index**, while the **NET redemption uses the post-rebase index**. This is asymmetric: the same shares redeemed for NET yield more than for sNet when an epoch is due. The PRD §6.2 single SY budget rule still holds (the shares are accounted once), but the **`tokenOut`-asymmetric output** is a real source feature. Plan §6.5 must record this; users choosing NET output near an epoch boundary get strictly more than sNet output. Confirmed fact.

- **Counterargument C (caller-receipt measurement is not in the SY)**. The SY's `redeem` enforces `minTokenOut` against the computed `amountTokenOut`; it does not perform a balance-delta check after the external transfer. The hook must therefore perform its own balance-delta check. The PRD §6.1 requires this generally; the SY source specifically does not. Plan §6.5 must require the hook to perform the balance-delta check; otherwise a misbehaving `net`/`sNet` token could pass `minTokenOut` and revert without delivering. Confirmed fact.

- **Counterargument D (the wrapper implementation is absent)**. Only `IPDecimalsWrapperFactory.sol` is in the verified compilation; the wrapper implementation body is not. The SY proxy's `scaledNet` and `yieldToken` addresses are produced by an external on-chain wrapper factory. The hook author must therefore not assume the wrapper implementation behaves in any specific way beyond the standard 18-decimal-wrapper interface (mint/burn/transfer). The hook cannot compose with the wrapper internals. Confirmed fact.

- **Counterargument E (`_syncedIndex()` projection is not the on-chain committed state)**. `_syncedIndex()` simulates the rebase; the actual `IStakedNet(sNet).index()` does not advance until someone calls `stake`/`unstake`/`rebase()`. A pure quote therefore simulates a state that the chain has not yet committed. This is acceptable for a quote but must be recorded. Confirmed fact.

- **Counterargument F (checked-arithmetic overflow domain on the inverse)**. `shares * _syncedIndex()` can overflow uint256 for large share inputs because `SY.totalSupply()` is a uint248 (`PendleERC20Upg.sol:687`) and `_syncedIndex()` can be near `INDEX_GONS ≈ 1.157e68`. The product is up to `2^312`, well above `2^256`. The hook must guard share inputs. Confirmed fact.

## 12. Missing evidence / unresolved

- The **wrapper implementation** (`contracts/wrappers/PDecimalsWrapper.sol` or equivalent) is **not in the verified compilation**. The SY proxy's `scaledNet` and `yieldToken` rely on it. Local NetNet repository evidence on the wrapper behavior is missing. Engineering consequence: the hook must use the SY ERC20 (the 18-decimal scaled wrapper of sNet) as the share token, not raw sNet, and must convert back to raw sNet/NET via the source-verified `previewRedeem` / `_redeem` formulas. MiniMax M3 does not have access to the wrapper implementation body from this extraction. (Confidence: high; the absence is reported, not filled.)
- The **on-chain Staking rebase flow** that mirrors the `_syncedIndex()` projection is at `lib/crane/contracts/protocols/pol/net/src/Staking.sol:128–151`, but the **StakedNET `sNet.rebase(distributed, _epoch.number)`** body that performs the actual `index = INDEX_GONS / (TOTAL_GONS / newSupply)` is **not** in this verified compilation. Plan §6.5 must specify that the local `Staking.sol` is a reference body, not deployed equivalence. (Confidence: high; the file is marked as a reference snapshot 2026-09-24.)
- The actual **Pendle market, PT/YT** identities, factory and router addresses are G1 evidence and are not in this verification round. They are referenced by the hook but not verified by the SY compilation. (Confidence: pending G1.)
- The **oracle terms** for bond duration, opening price, seigniorage fraction are G1 evidence; not in this round. (Confidence: pending G1.)
- The **`rebasingClaimToken` (`sNet`) decimals** are G1 evidence. The SY source does not declare them; the wrapper factory chooses 18 for the SY ERC20 but the **raw `sNet` decimals are needed to interpret `previewRedeem` outputs**. (Confidence: pending G1.)
- The **execution-time difference** between the `_deposit(net)` `IStakedNet(sNet).index()` path and the `_previewDeposit(net)` `_syncedIndex()` path is real; the plan §6.5 / W3 should specify a hook-side correction (`preview * live / synced`) or a pre-`rebase()` to align. (Confidence: high; concrete fix recommendation.)
- The **`redeem(net)` → `unstake` post-burn revert** is real (the share burn precedes the unstake). The hook must absorb the burn if unstake reverts. Plan §6.5 / W3 / W6 must specify this guard. (Confidence: high.)
- The actual **chain/runtime behavior** of `MAX_SNET_SUPPLY` clamping has not been observed. The compile result is verified at `2026-09-04T08:05:04Z`; runtime/upgrade events since then are unobserved. (Confidence: pending block-pinned observation; PRD §4.5 distinguishes "verified" from "live".)

## 13. Source URLs, paths, versions, access dates

- Sourcify primary source: <https://sourcify.dev/server/v2/contract/4663/0xAdAb46E7024d34E18BeBB058D374aa1069DB461E?fields=sources> — accessed 2026-09-28 via `VERIFIED_SY_SOURCE_EXTRACTS.md`; round-tripped against keccak256 `0xb0183ce8e725d1541d8f58795f6142e8b0d7b98c5db3793e638d2061744b966b`. Compilation metadata: solc `0.8.30+commit.73712a01`, optimizer `1,000,000`, `viaIR=true`, `evmVersion=Cancun`, Sourcify match `47105638`, verified `2026-09-04T08:05:04Z`.
- Local IndexedEx build config (`foundry.toml:1–5,29–36`): solc `0.8.35`, optimizer runs `1`, `via_ir=false`, default/fork product profiles. Local build is **not** the deployed build; the deployed bytecode is on-chain.
- Pendle `IStandardizedYield`: <https://docs.pendle.finance/pendle-v2-dev/Contracts/StandardizedYield> — accessed 2026-09-27 (PRD §16.2). PRD §4.5 caveat: "preview functions as best-effort, unaudited for on-chain use" — confirmed by verified source: `_previewDeposit` differs from `_deposit` for the `net` branch.
- Local references:
  - `docs/strategies/ohm-style/netnet-pendle/NETNET_PENDLE_DETF_PRD.md` v0.33 (revised 2026-09-27).
  - `docs/strategies/ohm-style/netnet-pendle/NETNET_PENDLE_DETF_IMPLEMENTATION_AND_TEST_PLAN.md` v0.7 (2026-09-27).
  - `docs/strategies/ohm-style/netnet-pendle/PRD_OPEN_QUESTIONS.md` (2026-09-27).
  - `docs/research/netnet-sy-conversion-2026-09-27/VERIFIED_SY_SOURCE_EXTRACTS.md` (2026-09-28).
  - `lib/crane/contracts/protocols/pol/net/src/Staking.sol` (local reference snapshot 2026-09-24).
  - `lib/crane/contracts/protocols/dexes/balancer/v3/utils/BalancerV3WeightedPoolQuote.sol:14–49`.
  - `lib/crane/contracts/external/balancer/v3/vault/contracts/BasePoolMath.sol:50–107,126–397,277–343,359–398`.
  - `contracts/hooks/uniswap/v4/standardExchange/weighted/UniswapV4StandardExchangeWeightedBufferHookMath.sol:16–528`.

## 14. Status of L3 / L4 / NN-10 / NN-07

- **L3** (source-derived conversion specification). Source extraction completed 2026-09-28. Body inspection recorded in this document. Source-mapping of internal-share bookkeeping, off-source wrapper behavior and on-chain StakedNET `sNet.rebase` implementation body is **not closed**; this remains plan §6.5 + W3 + W12 work. MiniMax M3 considers L3 **partially closed** by this round: branch table, formula inspection, forward/inverse derivation, fixed-state inverses, integer-domain checks, caller/internal-share custody, and recompute/rollback are closed; the wrapper implementation body is not closed.
- **L4** (terminal late-proceeds). Not modified by this round. PRD §12.4 / plan §2.2 retain the unresolved edges. This document does not open new L4 questions.
- **NN-10** (reusable SY provider). Reusable provider rate derivation is now expressible from the verified source: per-share rate = `previewRedeem(tokenOut, 1)` in the requested target's native units, normalized by `1e18` for the SY ERC20 18-decimal unit. This is engineering authorable. NN-10 remains **OPEN** until the provider implementation is written and validated against the verified conversion. MiniMax M3 considers NN-10 **ready to implement** based on the verified formulas.
- **NN-07** (quote, funding, settlement transitions). The SY leg is now expressible at the source-derived level; ordinary NET/sNET output funding is fully specified in §7. NN-07 remains **OPEN** as plan §6.4 §6.5 + W3 + W6 + W7 work; the SY-specific branch is closed.

## 15. Confidence summary

- High: branch table, formula inspection, fixed-state inverses, checked-arithmetic domain, caller/internal-share custody, recompute/rollback sequence, `_syncedIndex()` projection versus current-index divergence, `MAX_SNET_SUPPLY` clamping, the absent wrapper implementation, the `_deposit` vs `_previewDeposit` divergence on the `net` branch.
- Medium: the on-chain `MAX_SNET_SUPPLY` clamping behavior under actual queued profit (not observed at runtime).
- Low / pending: the wrapper implementation body, the on-chain `sNet.rebase` implementation body (mirror from local `Staking.sol` is reference only), the exact `sNet` decimals, the chain/runtime behavior of the cap.

## 16. Saved full-original path

`docs/research/netnet-sy-conversion-post-extraction/minimax-original.md` (this file).