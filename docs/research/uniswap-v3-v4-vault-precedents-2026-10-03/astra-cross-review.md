# Astra — external-vault-precedents combined cross-review

**2026-10-03.** Continued Astra session. Read all three complete current originals together: Grok replacement, MiniMax M3 and Kimi K3. No peer reviews, syntheses or status artifacts read. Originals unchanged. Source claims below were checked against primary material, not accepted by attribution alone. Research only; no execution, implementation, delegation, gas measurement or consensus claim.

## 1. Outcome and evidence changing my view

The strongest new positive findings survive scrutiny, but not their broadest classifications:

1. **Aperture genuinely computes swap sizing on-chain without binary search.** Its general algorithm still discovers the terminal tick interval before using a quadratic. This is stronger evidence than an off-chain zap, weaker than a strict no-discovery solution for the complete incumbent vault book.
2. **ICHI supplies a concrete depositor-adverse spot/TWAP mint rule.** Grok's address lead allowed me to recover indexed primary verified-source excerpts for both deposit and withdrawal, reducing a gap in my original. Crucially, its hysteresis branch is **not a hard maximum-deviation gate**: it checks the latest observation's timestamp when deviation is large.
3. **DualPool is a useful V4 accounting reference, not a fungible scalar vault.** At Kimi's pinned revision, shares are explicitly non-transferable internal ledger entries. This additional incompatibility was missing from the other originals' summaries.
4. **Beefy genuinely admits a limited deficit-side scalar contribution.** It neither universally accepts unilateral deposits nor returns a scalar payout in the inspected core. I retain my source-versus-later-docs distinction on imbalance fees.

My ranked research shortlist remains Aperture analytic sizing, ICHI conservative valuation, Arrakis direct splitting, and Beefy/Charm bounded management. This is a shortlist of **mechanisms to combine and verify**, not a claim that any inspected product already meets every autonomous Orbital/SY requirement.

## 2. Aperture: analytic solution, interval discovery, and ownership boundary

Re-read pinned [`OptimalSwap.sol`](https://raw.githubusercontent.com/Aperture-Finance/uniswap-v3-automan/c40aaa98cf49baf454fbb7a8ee6709862e27038e/src/libraries/OptimalSwap.sol), commit `c40aaa98cf49baf454fbb7a8ee6709862e27038e`.

`getOptimalSwap` initializes active liquidity, spot, range, fee and desired token amounts; calls `crossTicks`; then uses `solveOptimalZeroForOne`/`solveOptimalOneForZero`. `crossTicks` has `do ... while(true)`, evaluates the next tick using remaining available input and stops when the next tick cannot be reached or `isZeroForOne` changes sign. **The final amount is being discovered during this walk.** It is not traversal of an input amount already fixed by the caller.

Therefore:

* **Agree with MiniMax** that the terminal solve is real on-chain analytic code and relevant mathematical counterevidence.
* **Correct MiniMax's “NOT iterative” description:** the complete algorithm iterates over ticks; no application work cap was identified in this function.
* **Correct Kimi's blanket class-B/off-chain classification:** the empty-`swapData` path in `Automan._optimalSwap`/`SwapRouter._optimalSwapWithPool`, read in my original, invokes this algorithm directly. Aggregator calldata is optional on that path. The product is NFT automation, class E for fungible-vault comparison, with an on-chain conversion mechanism—not simply class B.
* **Grok's broad claim that scalar entry exists only as valuation must be narrowed.** A synchronous on-chain conversion entry is implemented here, albeit for a position rather than a common-book vault.

For an interior constant-L segment, fee complement g=1−f, spot sqrt s and range sqrt endpoints a,b, the continuous target can be written:

`x'=x−L(1/t−1/s)/g`, `y'=y+L(s−t)`, with `x'/(1/t−1/b)=y'/(t−a)`.

Clearing this equation yields the quadratic implemented with Q96 approximations and clamps. It does **not** solve `(c−swapIn)*B1_after=swapOut*B0_after` when the incumbent book includes arbitrary F, E, multiple ranges and owned-LP fee growth. No whole-book share supply or fee ownership appears in `SwapState`.

**No-binary-search verdict:** positive precedent. **Strict no-discovery verdict:** general path fails that narrower test; a single-initial-segment, exact-certified variant is a candidate. Integer liveness, fee rounding and incumbent attribution remain proof obligations. No source gas comment or article figure is adopted as a measured result.

## 3. ICHI: now a more precise positive precedent

Primary verified-source page: [Celo ICHIVault 0x07fddb65631529df92e87e536aa9aeec8ba1d020](https://celoscan.io/address/0x07fddb65631529df92e87e536aa9aeec8ba1d020). The direct fetch was dominated/truncated by explorer chrome; targeted public search returned source bodies indexed from that same primary page. This is **indexed verified-source evidence**, not a complete source archive or independent runtime match.

For source precision Z, spot P, TWAP T, pre-intake book B and supply S:

```
Plo = min(P,T); Phi = max(P,T)
depositValue = c1 + floor(c0*Plo/Z)
bookValue = B1 + floor(B0*Phi/Z)
minted = S==0 ? depositValue : floor(S*depositValue/bookValue)
```

Deposit checks allowed sides, positive contribution, strict per-side deposit maxima, recipient and post-mint supply cap; updates base/limit fees before pricing; pulls declared input. It does not execute a composition swap. This directly improves my original's documentation-only assessment of ICHI.

**Grok's equation is substantially confirmed, with one correction:** deviation divides by `max(P,T)`, not always P. More importantly:

```
if delta > hysteresis: require(checkHysteresis())
checkHysteresis(): latestObservation.blockTimestamp != block.timestamp
```

Large deviation can therefore pass when the last observation is not timestamped in the current block. **Kimi's characterization as an ordinary bounded spot/TWAP gate is too strong**, as is “only gated by hysteresis”: side permissions and deposit/supply caps also apply. This timestamp check is a particular anti-manipulation heuristic, not a freshness guarantee, cross-block manipulation proof or independent oracle.

The indexed `withdraw(shares,to)` body removes proportional base/limit liquidity and transfers proportional unused token0 **and token1**. This closes Grok's untraced-exit gap and supports Kimi/my original's basket-exit observation. It does not prove that every ICHI version or integration has identical semantics.

**Derived reuse opportunity—not a source API:** with frozen positive prices/book/supply, requested m shares needs `v_req=ceil(m*bookValue/S)`. Token0 input can be sized as `ceil(v_req*Z/Plo)`; token1 as `v_req`. Apply all original gates and integer-domain checks. That direct inverse could replace an outer input-sizing loop after deliberate API/ownership approval. It is not the inverse of a swap-bearing exit.

**Wrappers:** indexed Celo/Linea guard ABIs expose `forwardDepositToICHIVault(...minimumProceeds...)` and dual-output withdrawal minima. The base deposit signature lacks a user share-minimum argument. Wrapper enforcement and refund/funding internals must still be traced; ABI names alone are not proof. I did not decode bytecode or infer execution from it.

**Reject MiniMax's oneToken conflation.** The freshly read [oneToken repository README](https://raw.githubusercontent.com/ichifarm/ichi-oneToken/master/README.md) identifies OneTokenFactory, OneTokenV1 and Incremental Mint Master. That does not establish the ICHIVault mint formula or YieldIQ control path. MintMaster/maxOrder/PeggedOracle facts cannot be transferred to the base/limit vault by shared brand. The guessed oneToken Solidity path returned 404 and was not retried; no exact oneToken accounting claim is made here.

## 4. Beefy: both peer extremes need correction

Freshly re-read the [pinned BeefyVaultConcLiq](https://raw.githubusercontent.com/sherlock-audit/2024-05-beefy-cowcentrated-liquidity-manager/42ef5f0eac1bc954e888cf5bfb85cbf24c08ec76/cowcentrated-contracts/contracts/vault/BeefyVaultConcLiq.sol), Solidity 0.8.23, MIT. Its Uniswap strategy was read in my original at the same revision.

`_getTokensRequired` accepts the underweight side first, up to equal marked values, then requires complementary value. **Kimi's “single-token only through zap” is overbroad:** direct deficit-side scalar entry exists. **MiniMax's broad class-A/arbitrary scalar entry is also wrong:** balanced or wrong-side books do not supply that general admission.

For accepted c, source mint is:

`m=floor(S*(c1+floor(c0*P/10^36))/(B1+ceil(B0*P/10^36)))`.

`strategy.price()` is pool-spot-derived, not a price-free internal invariant or “Uniswap SDK on-chain.” `beforeAction` claims earnings/removes all liquidity; `strategy.deposit` redeploys main/alt and is calmness-gated. Strategy balances exclude locked profit and pending fee accounting. Withdraw sends **both** pro-rata amounts. This is D admission in a restricted domain, basket exit, and a two-position placement mechanism; “class A on placement” changes the task's classification definition and must not be used to imply full scalar capability.

Later official CLM documentation describes an imbalance fee and aggregator scalar UX. The earlier pinned vault does not implement that later-described fee. Neither the source nor a quote from the documentation's warning about unrestricted single-sided deposits establishes the exact current fee schedule. My original kept these versions separate; that remains necessary.

The two-position design is highly useful, but remove-all/re-add user workflows cannot be transplanted into already-unlocked sleeve-only calls. “Live/audited/deployed” claims also require a deployment revision and audit scope; a submitted audit snapshot and product page do not establish the selected code's release status. No foreign batch quota should be introduced under current D11 without an explicit policy change.

## 5. Gamma: version differences and the missing admission gate

**Grok and Kimi describe different source revisions.** Grok pins older `519117704a67659273b78658ad43bcad8a8073ce`; Kimi/my original inspect master labeled Hypervisor v1.3. Owner `swapQuantity` in the earlier version and a swap-free later rebalance are not necessarily contradictory. Preserve the revision boundary.

Freshly re-read [ClearingV2.sol](https://raw.githubusercontent.com/GammaStrategies/hypervisor/master/contracts/ClearingV2.sol), version 2.0.0. Its `clearDeposit` requires registered position, not paused, spot in base range, optional global/per-position TWAP check, and—unless `freeDepositList[pos][from]`—both deposits positive plus two ratio checks. Owners configure the exception list and gates.

**Correction to Kimi:** a whitelist selecting UniProxy does not itself make arbitrary unilateral admission permissionless; the actual Clearing policy matters. Nor does source presence of `checkPriceChange` prove every configured deployment has that check enabled.

**Correction to MiniMax:** UniProxy is not the swapper asserted in its report. The inspected proxy validates through Clearing then calls Hypervisor deposit; `getDepositAmount` is an on-chain view, even if frontends commonly call it. It does not acquire the other asset. Scalar permissioned bypass, basket funding and scalar conversion are different capabilities.

The exact spot-NAV formula is a real D mechanism. Its existence is not proof of safety or production “survival” due to a mandatory gate. A demonstrated exploit needs a complete costed money path; changing spot or donating assets alone does not prove profitable theft from that deposit function.

## 6. Arrakis and Charm: do not disqualify the wrong layer

Fresh primary reads: [Arrakis RouterSwapResolver](https://raw.githubusercontent.com/ArrakisFinance/v2-periphery/main/contracts/RouterSwapResolver.sol), [RouterSwapExecutor](https://raw.githubusercontent.com/ArrakisFinance/v2-periphery/main/contracts/RouterSwapExecutor.sol), and [Charm AlphaStrategy](https://raw.githubusercontent.com/charmfinance/alpha-vaults-contracts/main/contracts/AlphaStrategy.sol).

**Arrakis:** `calculateSwapAmount` is a direct on-chain calculation using caller-supplied price and current normalized inventory. For scalar token0, continuous split `x=c/(1+wP)`. Executor separately consumes `amountInSwap`, `swapRouter`, `swapPayload` and output minimum. This reconciles the peers' correct observation of supplied execution calldata with my positive discovery: sizing is not necessarily an off-chain numerical search, but the complete current call is not autonomous from a plain scalar amount. Fixed-price split ignores realized fees, price impact and incumbent repricing. Actual-fill basket sizing/refunds make the interface tolerant of residuals; that differs from current exact-in retained-credit law.

Arrakis core's requested-share basket mint also contains per-position rounded settlement debt; it should not be simplified to floor-only `m*B/S` as MiniMax does for proportional minting generally. Exact charged assets and fee exclusions remain version-specific.

**Charm:** AlphaStrategy derives spacing-rounded base/bid/ask bands on-chain, checks TWAP deviation, and calls `vault.rebalance(0,0,...)`. A keeper authorizes/times the operation but does not supply a searched swap amount to this strategy. **Kimi's dismissal of Charm because the vault accepts manager swap sizing misses this supplied zero-swap implementation.** MiniMax's Alpha/AlphaPro range-count, binary-exit and license claims do not match the Alpha source inspected in this session. Alpha is a two-range proportional basket vault; Alpha Pro is a separate product with full-range weighting. Neither should be presented as full scalar service.

Keeper-dependent management does not automatically make the deposit algorithm class B/E. Separate autonomous user arithmetic from operational maintenance trust/liveness. Local-first management is precisely where reuse is plausible.

## 7. Bunni and DualPool: useful V4 machinery, not class A

**Bunni.** My original traced Hub/HubLogic/Quoter and actual reserve paths, not just an audit excerpt. Existing two-positive-leg deposits are proportional; one-sided/zero-book LDF domains must not be flattened into “always requires both.” Withdrawal pays raw balances plus valued proportional ERC4626 reserve shares; that is not necessarily `floor(r*(raw+underlyingReserve)/S)` because the reserve-share floor and vault conversion occur separately. am-AMM queue requirements are conditional.

Fresh [RebalanceLogic](https://raw.githubusercontent.com/Bunniapp/bunni-v2/main/src/lib/RebalanceLogic.sol) sizes a Flood order on-chain using TWAP/density ratios and creates an order for external fillers. **Kimi's current-path ODOS/off-chain-sizing classification is not supported by this source.** Execution being filled later is distinct from who derives the amounts. **Grok's density-to-liquidity description is useful**, but effective trading-liquidity computation is not ongoing fungible-share valuation: existing share minting remains proportional. **MiniMax's withdrawal “iteration over subpositions” is not the read HubLogic path.** Do not attach OpenZeppelin ReHypothecationHook claims to Bunni as if they were the same code.

**DualPool.** Fresh pinned source at `5a584527d3026bb3b401a902ff0c4f4526b389c5`: [DualPoolHook](https://raw.githubusercontent.com/Uniswap/v4-hooks-public/5a584527d3026bb3b401a902ff0c4f4526b389c5/src/alf/DualPoolHook.sol), [PoolVault](https://raw.githubusercontent.com/Uniswap/v4-hooks-public/5a584527d3026bb3b401a902ff0c4f4526b389c5/src/alf/base/PoolVault.sol), [Shares](https://raw.githubusercontent.com/Uniswap/v4-hooks-public/5a584527d3026bb3b401a902ff0c4f4526b389c5/src/alf/types/Shares.sol), and [MultiAssetShareMath](https://raw.githubusercontent.com/Uniswap/v4-hooks-public/5a584527d3026bb3b401a902ff0c4f4526b389c5/src/alf/base/vault/MultiAssetShareMath.sol).

The math is `amount_i=shares*(B_i+1)/(S+10^offset)`, up for deposits/down for exits. But Shares explicitly says **no ERC20 share token, non-transferable ledger**. This is class C accounting plus an E composability limitation, not our fungible SE/SY surface. Even a zero real balance receives a +1 virtual asset term; do not infer general one-sided admission from a zero reserve.

`minDepositBlocks=0` disables the lock; a same-block ban is not universal. `removeLiquidity` explicitly opens `poolManager.unlock` and redeems claims before payout, failing a nested call in the same manager. Additions are owner/open-deposit gated, both-token share-denominated operations; `getIndicativeQuote` explicitly is not an exact execution prediction. These are material qualifications to the peers' suggested transplant.

A source-comment sanity check: at bootstrap S=100v, virtual dilution v/(S+v)=1/101≈0.99%, not ppm. One comment describes this threshold as ppm-or-better while another correctly calls it ~1%. Do not convert a comment or project reputation into a proved security property. Likewise gross asset accounting and immediately realizable liquidity are intentionally different views; neither foreign view should silently replace Orbital's configured shares-times-rate law.

## 8. Classification, licensing and evidence corrections

**Class A must remain a product-level test.** Deterministic placement, a basket withdrawal, or an ERC4626 share ledger is not “class A on one component.” MiniMax's A entries for Beefy, Bunni and Arrakis do not satisfy the required scalar-in/scalar-out vault definition. Conversely, no claim that the world contains only two entry families, every scalar exit has one implementation, internal CP is the only oracle-free design, or exact-output scalar exits are unsupported everywhere is established by these samples. Kimi's headline and “settled externally” language must become coverage statements. Grok's narrower “no traced complete match” is defensible if same-pool spot pricing is recorded as an economic disqualifier rather than covertly changing the computational definition of A.

**Evidence completeness:** my original's “deep trace” means the specified money-path files/functions were read, not that every dependency, UI, deployment or audit revision was closed. ICHI was documentation-level in that original; this review adds source excerpts but still lacks complete wrapper/runtime/license closure. DefiEdge remains documented unilateral local admission, not proved code—Kimi's untraced class C label should be tentative. Named projects or broad repo links alone cannot support MiniMax's “eight complete traces.”

**Licenses:**

| Inspected source | Actual evidence and correction |
|---|---|
| Aperture OptimalSwap at c40aaa98… | BUSL-1.1 header, not MIT. Fresh [pinned license](https://raw.githubusercontent.com/Aperture-Finance/uniswap-v3-automan/c40aaa98cf49baf454fbb7a8ee6709862e27038e/LICENSE) names 2026-07-01 change date and GPL-2.0-or-later change license. Assess applicability/obligations, not blanket permission or blanket permanent ban. |
| Charm AlphaVault/AlphaStrategy main | Unlicense/0.7.6, not MiniMax's BUSL claim for these files. Alpha Pro requires separate evidence. |
| Gamma master Hypervisor/UniProxy/ClearingV2 | BUSL-1.1/0.7.6, not MIT. No deployment/license-change conclusion inferred. |
| Arrakis V2 inspected core / resolver/executor | Core BUSL-1.1, inspected periphery UNLICENSED, 0.8.13. MiniMax's blanket GPL-3.0 is unsupported for these files. |
| Beefy pinned audit vault/Uniswap strategy | MIT/0.8.23. Audit snapshot identity does not attest current deployment. |
| DualPool pinned files above | MIT/0.8.26; closes Kimi/Grok's per-file license gap, not all transitive obligations. |
| Bunni inspected Hub/logic/quoter | MIT headers; repository explicitly says some other files AGPL. Avoid a blanket repository-level permissive conclusion. |
| ICHI | oneToken README's BUSL statement belongs to oneToken; it does not settle ICHIVault's license. |

MiniMax's V3 position identity is wrong. Fresh primary [V3 Position.get](https://raw.githubusercontent.com/Uniswap/v3-core/main/contracts/libraries/Position.sol) hashes owner/lower/upper **without salt**. V4 adds salt within each pool. V3 NFT periphery can maintain multiple NFTs atop its core custody ledger; that does not add a core salt field. Distinguish direct-position managers such as the inspected Beefy Uniswap strategy from NFT wrappers.

Audit issues and reproduction gists are not automatically confirmed incidents or proved vault-mint attacks. External lending-oracle findings must not be relabeled ICHI admission exploits. My conclusion on Bunni remains only the project's primary README warning; no exploit figures or causal account are needed here. Source gas estimates and “industry-proven”/“audited live” labels do not substitute for pinned measured evidence.

## 9. Ranked reusable shortlist and remaining scalar integration work

1. **Aperture terminal analytic sizing + direct-pool scalar-target realization.** Best positive no-binary-search mechanism. General interval discovery remains; strict variant needs a one-segment certificate and whole-book derivation.
2. **ICHI conservative spot/TWAP mark and local unilateral admission.** Now source-supported for this deployment's excerpt. Its direct frozen-state input inverse is derivable; timestamp hysteresis and actual LP spot composition still require economic review. No scalar exit supplied by the core.
3. **Arrakis deterministic split, post-fill accounting and residual policy.** Direct arithmetic can be autonomous when paired with a fixed supported executor; current supplied calldata is not that executor design. Exact full-consumption alignment is not established.
4. **Beefy restricted deficit admission plus Charm/Beefy bounded base/alt placement.** Useful for inventory absorption and no-swap management, but deficit-only entry cannot be the sole mandatory-scalar route. Do not call a basket core the final product.
5. **DualPool/Bunni accounting separation and liquidity-availability modeling.** Reuse concepts, not their nontransferable/queued/nested-unlock-incompatible surfaces.

| Mechanism | No binary search? | Strict no sizing discovery? | Remaining barrier |
|---|---|---|---|
| Aperture general optimizer | Yes in inspected optimizer | No: terminal segment discovered | Incumbent F/E/owned-fee/share model; V4 settlement |
| Aperture one-segment solver | Yes | Candidate yes with one certificate | Integer validity, useful domain and whole-book adaptation unproved |
| ICHI local admission | No swap-sizing search visible | Yes for extracted mint arithmetic | Gate/wrapper closure, valuation economics, scalar exit/local cover |
| Arrakis fixed-price estimator | Yes | Yes for estimator | Impact/fees/residuals and fixed autonomous executor |
| Beefy deficit selection | Yes | Yes for inspected admission selection | Restricted side/amount; pool-touching accounting; basket exit |
| Charm placement strategy | Yes | Bounded arithmetic placement | No scalar common-share admission/exit |

**Required Hookless/Orbital work is not erased by precedent:** scalar selectors and meaningful minima/maxima; actual current-call funding; complete D/F/E bookkeeping and own-fee attribution; same-manager already-unlocked F-only settlement; multi-position quote overlays; exact transition-state and rate-provider projection; any direct exact-share inverse; and supported versus rejected exact-output cells. No inspected external precedent solves `_faceForClaim`, `_invertBufferForEffective` and the separate `zapSplitWad` together. Fixed-state mint inversion does not invert rate changes or a redemption-plus-swap automatically.

Current PRD D1–8, D17–21/D25/D27/D30 require explicit updates for chosen admission, residual and management semantics; D15–16 funding/booking and D22 Pons separation remain. Preserve dual activation/dead sink and fixed 1/50/25/10 bp meanings unless the owner expressly changes them. Neither foreign timestamp gates nor deposit locks are silently approved.

**Human checkpoint:** choose strict no-discovery versus acceptance of bounded monotone interval discovery; choose the admission economics and residual treatment; then authorize a narrowly scoped proof/port plan retaining scalar entry and scalar exit. Later tests must independently reconcile fees/repricing/rounding, demonstrate nontrivial supported domains and manager-state parity, and measure complete nested calls under unchanged caps. This report authorizes none of that execution.

## 10. Access and limitations

All fresh evidence accessed **2026-10-03**. Context7 `/uniswap/v4-core` preceded fresh API claims; primary raw/blob/explorer URLs are above. Pinned code is source identity, not a deployed-bytecode or safety attestation. Unnumbered raw results are cited by exact function rather than invented line numbers.

Two new ordinary public paths returned 404 and were not retried: pinned `src/alf/libraries/MultiAssetShareMath.sol` (actual imported path subsequently discovered through Shares and read), and `ichifarm/ichi-oneToken/master/contracts/oneToken/OneTokenV1.sol`. The Celo direct page fetch was truncated; indexed primary source excerpts are explicitly labeled, and guard evidence remains ABI-only. No local missing path or guard/SDK denial occurred. No forbidden artifact reads or out-of-scope writes.

Confidence high in the verified classification, loop, permission, formula and SPDX corrections; medium in source-to-local reuse applicability; unresolved in complete autonomous scalar economic safety, integer liveness and performance. **Return to moderator/human and stop. One review only.**
