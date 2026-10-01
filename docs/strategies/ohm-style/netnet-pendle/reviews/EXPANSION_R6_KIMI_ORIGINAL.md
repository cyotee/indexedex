# EXPANSION_R6 — Kimi K3 ORIGINAL independent first pass

Actual Universal V4 DETF expansion behavior, traced from source 2026-09-25 (local snapshot; no tests run). Read: CLAUDE.md, DETF_ALIGNMENT_PRD.md D42–D52/§24.3, custom PRD v0.15 (`NETNET_PENDLE_DETF_PRD.md:7,26`), matrix, and the sources cited below. No peer artifacts.

## Current Universal behavior (facts, with citations)

**Formula** — `contracts/vaults/detf/common/core/DETFEpochNaturalExpansionLib.sol:33–46`:
```
epochs  = (now − lastExpansionTimestamp) / EPOCH          // floor; EPOCH = 8 hours (:11)
closurePerEpoch = mulDiv(rateWad, EPOCH, YEAR)            // floor; YEAR = 365 days (:10)
perEpoch = mulDiv(supply, price − 1e18, price)            // floor
perEpoch = mulDiv(perEpoch, closurePerEpoch, 1e18)        // floor
mint    = perEpoch * epochs                               // linear, NO compounding
mint <= 1 → 0                                             // dust gate (:45, :13)
```
Eligibility: reserve live, `price > 1e18` AND `price > mintThreshold`, both strict; equality mints nothing (:34–38). Defaults: rate 0.10e18/yr (:12), mintThreshold 1.05e18, burn 0.95e18 (`DETFThresholdPolicy.sol:16–17`); PkgArgs zero → defaults (`UniswapV4DetfDFPkg.sol:247–248,263–265`).

**Price source** — `_highestSyntheticPrice` (`UniswapV4DetfCommon.sol:324–341`): iterates ALL hook pair tokens, prices each against its own `creationOfPair` rate (:337), takes the highest — not NET-only. The adapter (`.../weighted/UniswapV4StandardExchangeWeightedBufferHookExitQueryTarget.sol:89–140`) computes a marginal weighted spot mark of non-DETF inventory (`marked`, :117–130), scales by `ownedLp/lpSupply` (:134), divides by DETF supply (:136–138) and by the leg's creation rate (:139). This is a **view mark, not an executable swap quote**; nothing liquidates reserves.

**Clock/anchor/catch-up** — 8-hour wall-clock boundaries anchored at first bond (`UniswapV4DetfRepo.sol:178–179`: timestamp 0 → `block.timestamp`); **no NET-epoch synchronization**. Catch-up is linear over all completed epochs with no caps (D52, `DETF_ALIGNMENT_PRD.md:92,995`); the clock advances through completed boundaries even when mint is zero (`DETFEpochNaturalExpansionLib.sol:50–57`), so a zero-mint interval still consumes time.

**Destination** — minted DETF goes to the DETF itself then `IStakedDETF.fundRewards` (`UniswapV4DetfCommon.sol:373–380`), funding staking rewards; distribution per D47/D49/D50 (eligible stake at the boundary; one aggregate distribution; `DETF_ALIGNMENT_PRD.md:87–90,977–995`).

**Triggers** — mint path (`UniswapV4DetfTarget.sol:275`), stake (:347), unstake (:367), and bond/redeem routes (:418, :433, :545); plus permissionless `synchronizeRewards()` (`UniswapV4DetfMaintenanceTarget.sol:16–28`) — any caller when unlocked; wired children get a no-op callback. Pending amount is also included in quote previews (`UniswapV4DetfCommon.sol:183`).

**Hand example** — supply 1,000,000 DETF, price 1.10e18, default rate, 25 h elapsed (3 epochs): closurePerEpoch = floor(0.10e18×28800/31536000) ≈ 9.1324e13; perEpoch = floor(floor(1e6×0.10e18/1.10e18)=90,909 × 9.1324e13/1e18) = 8; mint = 24 DETF (≈0.00091% of premium per epoch). Effective per-epoch supply growth ≈ 0.0008% at 10% premium — far from a flat 0.5% of supply.

**High opening ≠ automatic premium** — synthetic price divides reserve-per-DETF by the leg's **creation** rate (:139). If the first bond mints G+B+R at 1,000 NET/DETF with matching reserve contribution, synthetic ≈ 1 at opening; premium appears only if reserve-per-DETF later exceeds the creation rate. Exact bootstrap equality is unverified.

## Reuse vs modify for the custom family (inference)

Owner selections differ from Universal in four places: (a) gate strictly > 1 NET/DETF vs default 1.05e18 threshold — settable via PkgArgs, no formula change; (b) NET-denominated gate vs highest-of-all-legs — requires restricting `_highestSyntheticPrice` to the NET leg; (c) processed-NET-epoch cadence vs 8h wall clock — requires replacing the timestamp anchor/epoch check with the selected NET-state synchronization (PRD §9), an already-selected departure needing formal reconciliation; (d) a flat 0.5%-per-epoch rate would replace the premium-closure formula entirely — NOT selected mechanics (PRD v0.15:26 says basis/gate/catch-up unresolved). Recommend reusing the lib's floor-order, dust gate, single aggregate catch-up and fund-through-staking destination; modifying only the price source (NET-only) and clock (NET epochs), with the rate question answered before choosing formula vs flat rate.

## Uncertainties

Lines 418/433/545 caller names not individually opened. `UniswapV4DetfRepo.sol:178–179` anchor context assumed to be first-bond activation per matrix P5. No live deployment, test execution or economic-safety verification.

Researcher: **Kimi K3** — assigned metadata `kimi-code-plan-global/k3` (variant high); routing metadata only, no provider attestation.
