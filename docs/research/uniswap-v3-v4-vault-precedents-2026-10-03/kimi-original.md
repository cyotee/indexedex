# Kimi K3 original — external V3/V4 vault precedent search

**Date:** 2026-10-03 (all sources accessed this date). Independent first pass for this round; no peer artifacts read. Research only; no consensus, no gas claims. Test applied throughout: synchronous scalar deposit **and** withdrawal, fungible shares, deterministic on-chain sizing an autonomous buffered-pool call (Orbital) can supply — no router/off-chain calldata, no binary search. "Upstream `main`/`master` is not a deployment pin" applies to every repo below.

## 1. Headline finding

**No public vault implements permissionless deterministic scalar exit without either a pool swap or an oracle/TWAP-priced admission — but the production patterns are highly instructive and mostly confirm our design space rather than refute it.** Every scalar *exit* found is proportional-exit-then-swap-the-entire-other-entitlement (our existing F6 pattern, validated externally). Every scalar *entry* is one of: (B) aggregator zap with off-chain calldata, (D) spot-NAV mint gated by an on-chain TWAP/deviation check, or (C) proportional basket. The strongest positive discoveries: **ICHI's permissionless on-chain hysteresis TWAP gate on single-token deposits**, **Gamma's exact spot-NAV mint formula (with its mandatory gate)**, **Beefy CLM's alt one-sided "limit order" position 1 tick outside the current tick plus swap-free re-centering**, **Uniswap Labs' own V4 DualPoolHook/PoolVault share accounting with EIP-4626 virtual offsets and multi-range buckets**, and **Blueberry's spell as the canonical sized-conversion exit**.

## 2. Deep traces (7)

### 2.1 Gamma Hypervisor v1.3 + UniProxy v1.2.3 — class D (the exact NAV mint)
Source: `https://raw.githubusercontent.com/GammaStrategies/hypervisor/master/contracts/Hypervisor.sol` (BUSL-1.1, pragma 0.7.6) and `.../master/contracts/UniProxy.sol`.
- `deposit(deposit0, deposit1, to, from, inMin)` explicitly "allows for arbitrary liquidity provision: one-sided, lop-sided, and balanced" (contract NatSpec). Formula (verbatim from source): `price = FullMath.mulDiv(sqrtPrice*sqrtPrice, 1e36, 2**192)` (spot); `shares = deposit1 + deposit0*price/1e36`; if `total>0`: `shares = shares*total/(pool0*price/1e36 + pool1)` where `(pool0,pool1)=getTotalAmounts()`. **This is single-token spot-NAV admission in token1 terms — the exact formula family we flagged as manipulable.** First deposit (total==0) mints `shares` raw with no ratio check.
- The gate is mandatory and off-vault: `require(msg.sender == whitelistedAddress, "WHE")` — only UniProxy may deposit. UniProxy v1.2.3 `deposit` requires `clearance.clearDeposit(...)` and post-mint `clearance.clearShares(...)`; the TWAP/deviation logic lives in the `IClearing` implementation (**not fetched — gap**). Caps: `deposit0Max/deposit1Max/maxTotalSupply`. Positions: exactly two (base + limit). `rebalance` is owner-only and **swap-free**: burn all → mint base with `getLiquidityForAmounts` → mint limit (single-sided residual) — no sizing search anywhere; swaps never happen inside the vault.
- Withdraw: proportional dual across both positions + unused balances (`_liquidityForShares` per position; `unused = balanceOf*shares/totalSupply`).
- Lesson: production survives spot-NAV only behind (gate + caps + proxy). For Orbital, the whitelist is deployment config; the TWAP check itself is an on-chain contract call, so the pattern is autonomous-compatible *if* the gate is permissionless.

### 2.2 ICHI ICHIVault — class D, permissionless TWAP-gated scalar entry (nearest miss / strongest counterexample candidate)
Sources: SDK `https://github.com/ichidao/ichi-vaults-sdk` (`deposit(amount0, amount1, ...)`, "One of the 'amount' parameters must be set to zero. Use isTokenAllowed()"); verified-source facts via `https://www.codeslaw.app/contracts/base/0x6f28872ed9b0dae3273f5d9eadbed224f8d24c19` (constructor `(pool, allowToken0, allowToken1, owner, twapPeriod, vaultIndex)`; `deposit(uint256,uint256,address) returns (shares)`; `hysteresis()/setHysteresis()`); hysteresis deposit check quoted from verified mainnet source in Sherlock issue `https://github.com/sherlock-audit/2023-02-blueberry-judging/issues/55`: `if (delta > hysteresis) require(checkHysteresis(), "IV.deposit: try later");`; guard contract `ICHIVaultDepositGuard.forwardDepositToICHIVault(vault, vaultDeployer, token, amount, minimumProceeds, to)` (LineaScan verified ABI, `https://lineascan.build/address/0x6337625bf843911da1e1eefaeafb5599c876469c`).
- Structure: two positions (base + limit), `getTotalAmounts = balanceOf + base + limit` (same shape as Gamma/Charm). **Deposits are permissionless single-token, gated only by the on-chain hysteresis spot-vs-TWAP check** — the only fully permissionless, on-chain, autonomous-compatible scalar-entry gate found. Withdrawal pays **both tokens proportionally** (SDK: "both vault tokens are added to the user's account") — so scalar *out* does not exist on-vault; integrators swap the other token (see 2.6).
- **Gap (honest):** the exact in-contract mint arithmetic was not captured (verified source fetch truncated; not retried in alternate form). Deposit-token-proportional mint with the TWAP gate is evidenced by the SDK/guard signatures and the hysteresis line, but I do not quote the formula.
- Primary incident evidence (not hearsay): Blueberry lending-oracle findings show `getTotalAmounts()`-based NAV is manipulable via spot composition and direct `balanceOf` donations — `sherlock-audit/2023-02-blueberry-judging` issues #20 and #55, and `2023-04-blueberry-judging` issue #84. These concern the *external lending oracle*, not the vault mint, but they document exactly the composition-skew residual a TWAP-gated NAV admission must bound.

### 2.3 Beefy CLM — class B scalar UX; the best production wing precedent
Sources: `https://github.com/sherlock-audit/2024-05-beefy-cowcentrated-liquidity-manager/blob/main/cowcentrated-contracts/contracts/strategies/velodrome/StrategyPassiveManagerVelodrome.sol`; product docs `https://docs.beefy.finance/beefy-products/clm`; article `https://beefy.com/articles/clm/`.
- Two positions: **main** = 50/50 `getLiquidityForAmounts` centered on current tick (width = `positionWidth × tickSpacing`); **alt** = "a 1-sided limit order just 1 tick outside of the current tick" holding the excess token. This is precisely our wing: swap-free deployment of residual inventory. `_addLiquidity` mints main from both balances, then alt from the leftover — deterministic, no probes.
- `isCalm()`: deposit/`setTicks` allowed only when `|tick − twap(120s)| ≤ maxTickDeviation` — another on-chain TWAP gate, here on the *management* path.
- `beforeAction()` on every deposit/withdraw: claim earnings + remove all liquidity → vault does exact accounting → `_addLiquidity()` re-deploys. Exact-fee accounting pattern worth studying.
- `moveTicks()`: privileged keeper (Gelato), swap-free re-center: withdraw all, harvest, re-add both positions. Single-token user UX exists **only** via ZAP with DEX-aggregator (1inch) calldata (docs, "How do I deposit into CLM?") — class B; an autonomous Orbital call cannot use it.

### 2.4 Arrakis V2 — class C canonical, manager-calldata maintenance
Source: `https://raw.githubusercontent.com/ArrakisFinance/v2-core/main/contracts/ArrakisV2.sol` (BUSL-1.1, pragma 0.8.13).
- `mint(mintAmount_, receiver_)`: `(amount0,amount1) = UnderlyingHelper.totalUnderlyingForMint(ranges, mintAmount_, totalSupply)` — proportional dual; init via `init0/init1` per-1e18 ratio. Multi-range: iterates `_ranges` (per-range `feeTier`, tick-spacing validated in `rebalance`), mints `liquidity*mintAmount/ts` per range. Optional `restrictedMint` gate.
- `burn`: proportional dual across all ranges + pro-rata leftover minus `managerBalance*`.
- `rebalance(Rebalance calldata)`: **onlyManager**; optional `swap{router, payload, expectedMinReturn}` against a whitelisted `_routers` set — **manager-supplied arbitrary swap calldata**: class B maintenance, explicitly unusable as an autonomous pattern (the council already flagged this shape).
- Reusable: multi-range registry with proportional mint/burn arithmetic and per-range liquidity scalars; `expectedMinReturn` + balance-delta verification pattern for any future manager swap.

### 2.5 Uniswap Labs DualPoolHook / PoolVault (v4-hooks-public) — class C, V4-native share accounting
Sources: `https://github.com/Uniswap/v4-hooks-public/blob/5a584527d3026bb3b401a902ff0c4f4526b389c5/src/alf/base/PoolVault.sol` (commit-pinned) and `.../src/alf/DualPoolHook.sol`; guide `https://developers.uniswap.org/llms.mdx/docs/protocols/uniswap-labs-hooks/dualpool/guides/provide-liquidity`.
- `bootstrap` mints `sqrt(amount0*amount1)` (V2-style, owner-only) and flips pool live. `addLiquidity(key, sharesToMint, maxAmount0, maxAmount1, deadline)`: **share-denominated proportional dual pull** with `previewDeposit` parity; `removeLiquidity` proportional dual with `minAmount0/1` enforced after transfer. Inflation defense: **EIP-4626 virtual offsets** — `amount = shares*(total+1)/(supply+10**offset)`.
- Multi-range: owner-configured `distribution` of tick-range **buckets** with weights; JIT cycle allocates via `getLiquidityForAmounts` at current price "so that no capital sits idle." ERC-4626 rehypothecation with `maxWithdraw`-first effective-liquidity sizing and `previewRedeem` fallback; ERC-6909 claim redemption inside `removeLiquidity`; `minDepositBlocks` same-block deposit→withdraw fee-sniping defense.
- Reusable for us: virtual-offset share math on V4, share-denominated dual interface with max-per-leg slippage, claim redemption on withdraw, anti-sniping deposit lock. Not scalar; deposits are auth-gated (`allowExternalDeposits` flag). **License not captured — gap** (check repo LICENSE before any code-level reuse).

### 2.6 Bunni v2 — class C deposits, class B rebalancing, V4-native architecture
Sources: `https://github.com/Bunniapp/bunni-v2` (BunniHub/BunniHook/BunniQuoter); Pashov review `https://github.com/pashov/audits/blob/master/team/md/Bunni-security-review-August.md` (quotes `BunniHub.deposit(DepositParams{amount0Desired, amount1Desired, amount0Min, amount1Min, refundRecipient, ...})` and `_mintShares(...actual amounts..., balances)`); `https://raw.githubusercontent.com/Bunniapp/bunni-v2/main/src/lib/VaultMath.sol` (MIT header; trivial `previewRedeem` helper); ecosystem writeup `https://research.auditless.com/p/bunni-how-to-build-a-leading-uniswap` (in-house rebalancer using **ODOS aggregation calldata**; am-AMM).
- Dual proportional deposits with per-leg mins and refund recipient — class C with honest refund semantics. Rebalancing sized off-chain (ODOS) — class B. Reusable: hub/quoter separation with preview parity; per-file MIT on `VaultMath.sol` (repo-level license unverified — gap).

### 2.7 Charm Alpha Vault — class C with the original wing
Traced in my own session history (prior rounds, same access date): `https://raw.githubusercontent.com/charmfinance/alpha-vaults-contracts/main/contracts/AlphaVault.sol` (Unlicense, 0.7.6): `deposit(amount0Desired, amount1Desired, ...)` proportional via `_calcSharesAndAmounts` (`shares = cross*totalSupply/total0/total1`); strategy-only `rebalance(int256 swapAmount, ...)` — manager-supplied swap amount; base order then single-sided bid/ask **limit order** for the residual. Confirmed again here as the archetype of "proportional core + one-sided residual wing + manager consolidation."

## 3. Wider inventory (classified, not deep-traced)

| Candidate | Class | Evidence |
|---|---|---|
| Steer Protocol | B | off-chain compute strategies sized off-chain |
| Aperture | B | intent/automation layer, off-chain planning |
| Revert Auto-Range/compounder | E | keeper tooling on user NFT positions, no fungible vault share |
| DefiEdge | C | dual deposits + keeper rebalancing |
| Range Protocol | C | proportional mint, manager rebalance |
| Mellow | C/E | strategy vaults, managed |
| Sommelier CL cellars | B | off-chain strategist instructions |
| Popsicle Sorbetto Fragola | C | dual proportional + keeper (no exploit claims made — no primary source read) |
| Unipilot | C (dormant) | dual + readjust keeper |
| Arrakis PALM | D/E | private, manager-directed, issuer one-sided bootstraps |
| Bunni v1 (V3) | C | dual proportional to vault composition |
| FlashiFi rehypothecation hook (V4) | C (hobby) | full-range, proportional FFRH shares, no audit evidence |
| Sorella/Angstrom | E | MEV DEX, no vault design found |
| Panoptic | E | options collateral, not analogous |
| Arrakis V1 (G-UNI) | C | `mint(mintAmount, receiver)` proportional (`https://github.com/ArrakisFinance/vault-v1-core`) |

**Class A (genuine on-chain deterministic scalar in *and* out): none found.** This is not an impossibility claim — it is a coverage statement over ~16 inventories and 7 traces.

## 4. Synthesis vs. Hookless/Orbital

1. **Exit side is settled externally.** ICHI integrators (Blueberry `IchiVaultSpell.withdrawInternal`, `https://github.com/sherlock-audit/2023-02-blueberry/blob/main/contracts/spell/IchiVaultSpell.sol`) do: `vault.withdraw(...)` proportional → swap the **entire** other-token balance exact-in via `pool.swap` with `MIN/MAX_SQRT ± 1` limits. Beefy/Gamma exits are proportional dual. No one sizes an exit swap by search; no one offers permissionless single-token-out without a conversion. Our F6 (sized full-conversion) is the industry pattern; exact-output scalar exit remains unsupported everywhere.
2. **Entry side has exactly two production families:** (B) aggregator calldata (Beefy Zap, most UIs) — useless for autonomous Orbital; (D) TWAP-gated admission — ICHI (permissionless hysteresis) and Gamma (proxy-gated spot-NAV `shares = (c1 + c0·p)·S/(B0·p + B1)`). Class D is therefore not "rejected exotic"; it is *the* production answer to mandatory scalar entry. Its documented residual (Blueberry #20/#55/#84): spot composition and `balanceOf` donations skew `getTotalAmounts` even when price is TWAP-gated; hysteresis bounds but does not eliminate it; Gamma adds caps and a trusted proxy. Our internal-CP admission (prior round) remains the only oracle-free alternative; the external world has no example of it in CL vaults — internal-invariant admission lives in V2-style zaps, not CL managers.
3. **Wings are production-standard.** Charm's bid/ask limit order, Gamma's limit position, Beefy's alt "1-sided limit order just 1 tick outside of the current tick," ICHI's base/limit: every serious manager deploys residual inventory one-sided and **swap-free**. Beefy's `_addLiquidity` (main then alt) and Gamma's rebalance (base then limit) are directly transplantable placement sequences with zero sizing probes.
4. **Accounting patterns to reuse:** Beefy `beforeAction` (remove-all → exact account → re-add); DualPoolHook virtual offsets + `minDepositBlocks` + claim redemption on withdraw; Arrakis V2 per-range proportional scalars and `expectedMinReturn` balance-delta checks.
5. **V3→V4 boundaries:** callback-driven V3 mint/collect vs V4 `unlock`/`modifyLiquidity` delta settlement and ERC-6909 claims (DualPool redeems claims on withdraw — our sleeve/cover logic must treat claims); NFT-position custody (Beefy/Velodrome) vs our salted PoolManager positions; V3 `observe` TWAP vs V4 hook/oracle access (our `UniswapV4MultiPoolTwapOracleTarget`); identical `LiquidityAmounts`/fee-growth math (Context7 `/uniswap/v4-core`, this date).
6. **Orbital-specific:** no precedent supplies an autonomous single-token buffered-pool leg; `_faceForClaim`/`_invertBufferForEffective` elimination via a closed-form exact-share inverse remains a Hookless-side choice; `zapSplitWad` unaffected by any external design found.

## 5. Ranked shortlist (reusable mechanisms)

1. **Beefy CLM placement sequence + `isCalm` management gate** — main/alt two-position, swap-free, deterministic; directly answers wing placement and consolidation. Nearest positive precedent to the owner's sketch.
2. **ICHI permissionless hysteresis TWAP gate** — the only autonomous-compatible scalar-entry gate found; pair with either NAV or internal admission.
3. **Gamma deposit formula + mandatory gate pattern** — exact NAV mint, reusable only with an on-chain permissionless gate and explicit acceptance of the composition-skew residual (bounds evidence: Blueberry findings).
4. **Uniswap Labs DualPoolHook/PoolVault** — V4-native share accounting (virtual offsets, bootstrap sqrt, deposit-lock, claim redemption).
5. **Blueberry sized-conversion exit** — validates current F6; no change needed.
6. **Charm/Arrakis** — architectural confirmation only; their manager-supplied swap sizing is disqualified for autonomy.

**Nearest miss overall:** ICHI — scalar in (gated), basket out. **Strongest disqualifier found:** none for class A by proof; by coverage, every scalar exit routes through a sized swap or async/managed path.

## 6. Economic mechanisms compared (per goal 6)

- **Fee-free virtual conversion (internal CP):** zero precedent in CL managers; avoids oracle risk; holders bear divergence (prior rounds).
- **Oracle/TWAP-marked admission (Gamma/ICHI):** industry standard; needs hysteresis width, caps, deviation gates; residual = composition skew + donation inflation (primary evidence above).
- **Manipulation gates:** `isCalm` (Beefy), `checkHysteresis` (ICHI), `IClearing` (Gamma) — all on-chain; widths are governance constants, not proven safe values.
- **Single-sided absorption:** Charm/Gamma/Beefy/ICHI all absorb imbalance one-sided without swaps — validates swap-free consolidation.
- **Fixed allocation vs optimized full consumption:** all production managers choose fixed deterministic placement; none optimize consumption on-chain — supporting "fixed allocation + residual booked" over search.

## 7. Licenses

Charm `Unlicense`; Gamma Hypervisor/UniProxy **BUSL-1.1**; Arrakis V2 **BUSL-1.1**; Bunni `VaultMath.sol` MIT (repo-level unverified); Beefy strategy (sherlock mirror) header not captured; DualPoolHook repo license not captured. **Gate:** BUSL code cannot be ported; formulas/architecture can be reimplemented — record a license review before any code-level reuse.

## 8. Gaps and next human decision

Gaps: ICHI exact mint arithmetic (source truncated, not retried); Gamma `IClearing` internals; Bunni/DualPool/Beefy repo licenses; Steer/Aperture/DefiEdge/Range/Mellow/Sommelier/Popsicle classified without primary traces; no deployment-version pins.
**Recommended decision:** choose the admission rule with eyes open — (i) internal CP (oracle-free, novel), or (ii) TWAP-gated NAV (industry-proven, bounded residual) — and adopt the Beefy/Charm two-position swap-free placement+consolidation and DualPool-style V4 share accounting regardless. No new implementation authorized by this document.
