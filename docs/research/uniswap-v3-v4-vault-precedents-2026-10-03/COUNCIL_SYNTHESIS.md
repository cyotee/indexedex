# External V3/V4 vault precedents — council synthesis

**Date/access date:** 2026-10-03. **Author:** Astra moderator. **Status:** four originals and four combined cross-reviews completed in the retained active sessions. Research and document authoring only; no implementation or measurements.

## 1. Answer: the search found real reusable solutions

**Yes: other projects have implemented useful parts of this problem, including a genuine on-chain optimal-swap algorithm without binary search.** This materially expands the earlier options. It is not justified to assume that single-token deposits necessarily require binary search, or that the only alternative is internal constant-product admission.

The strongest discoveries are:

1. **Aperture OptimalSwap:** on-chain piecewise analytic sizing, including swap-induced price movement. It discovers the final liquidity segment by walking initialized ticks, then solves a quadratic. No bisection over candidate amounts, but still sizing discovery in the general path.
2. **ICHI Vault:** direct scalar common-share admission using conservative spot/TWAP valuation, with side permissions, caps and a specific timestamp-based hysteresis heuristic. No deposit swap-sizing search in the extracted mint path.
3. **Arrakis V2 RouterSwapResolver:** a direct arithmetic split estimator. Its current execution accepts caller-supplied router data and handles post-fill residuals; the estimator is not an exact post-swap-whole-book solution.
4. **Charm Alpha and Beefy CLM:** concrete bounded base/main plus one-sided limit/alt management, with swap-free placement/redeployment. The human's wing proposal has clear precedents.
5. **Beefy deficit-side admission:** algebraically accepts the inventory-short token up to the imbalance. A useful middle ground, though insufficient as the only arbitrary scalar route.

**No inspected stack was verified as a complete drop-in meeting every requirement at once:** fungible common-book shares, both synchronous scalar directions, strict no-sizing-discovery, complete local/deployed/fee attribution, and autonomous local-cover operations while the same V4 PoolManager is already unlocked. This is a bounded coverage conclusion, not proof that no such design exists.

### What changes in the recommendation

Do not commit to bare internal CP merely because it is the only familiar direct formula. Research-backed alternatives now deserve explicit comparison:

- **If the real objective is avoiding repeated binary-search simulations:** prioritize Aperture's analytic algorithm and its bounded whole-book adaptation study.
- **If ordinary calls must perform no sizing discovery at all:** prioritize direct valuation admission (ICHI-style conservative marks as a reference, not an approved policy) with local-first custody, bounded Charm/Beefy-style wings, and a separately specified scalar exit/local-cover model.
- **If approximate conversion with explicit unused assets is acceptable:** Arrakis's direct split plus actual-fill accounting is a real alternative. This requires revisiting full-credit/no-refund and alignment semantics, not pretending the estimate consumes everything optimally.

Basket-only remains unacceptable as the final product. None of these recommendations authorizes a code port yet.

## 2. Search scope and evidence discipline

Researchers independently searched public project documentation, code, verified-source pages and audit snapshots, then each reviewed all three other original findings. The moderator independently searched again and fetched the decisive Aperture, Beefy, Charm, Arrakis and Gamma sources, ICHI indexed verified source, and V4 references. Retained session history existed, but no peer artifacts were read during this round's independent passes. Earlier cross-reviews were not shared.

The search covered more than a dozen named/versioned candidates in detail or at documentation level, with additional unclosed leads. Counts in individual originals are not additive and “deep trace” is not an audit of every dependency. The matrix below distinguishes actual code from documentation and incomplete evidence. Vendor gas claims, audit labels and deployment addresses do not establish measured local performance or production equivalence.

Classification: **D** direct valuation/inventory admission; **C** proportional-basket core; **B** caller/SDK/manager-supplied conversion; **E** nonfungible/private/async or otherwise not a direct analogue. No component is called a complete scalar vault merely because its placement formula is deterministic.

| Candidate/version | Evidence level | Finding and limiting distinction |
|---|---|---|
| Aperture UniV3 Automan / OptimalSwap | Pinned source + license; money-path researcher trace | Real autonomous analytic conversion; NFT position automation (E), not common-book vault accounting. Optional aggregator path is separate. |
| ICHI CL Vault, Celo address below | Indexed verified-source deposit/withdraw excerpts; official SDK | D scalar admission on enabled sides; core exit returns both currencies. Full wrapper/license/runtime closure incomplete. |
| Beefy CLM May-2024 snapshot | Pinned vault/strategy source; later official docs separately | D deficit-side admission, C basket exit, B aggregator UX; main+alt placement. Later documented fee is absent from this snapshot. |
| Charm Alpha | Full source on moving main | C admission/exit, on-chain zero-swap base/limit strategy; keeper-triggered, not keeper-supplied sizing in this strategy. |
| Charm Alpha Pro | Official technical reference | Separate product, configurable full-range/base/limit weight; not inherently full-range-only. Not source-closed here. |
| Arrakis V2 core/periphery | Full relevant money-path sources on main | C+B; direct split resolver exists, current execution consumes supplied payload; exact per-position settlement rounding matters. |
| Arrakis V1 / G-UNI | Researcher source-level proportional precedent | C; do not apply V2 licenses or current modular semantics to V1 by brand. |
| Arrakis Modular public / Pro private | Official docs/indexed material | Public-router versus issuer-owned/private strategy products differ; current Pro is not automatically a permissionless scalar vault. |
| Gamma Hypervisor v1.3 / UniProxy v1.2.3 / ClearingV2 2.0.0 | Full relevant sources | D spot-value formula internally; normal Clearing path requires both positive amounts and ratio bands. Privileged bypass is not public scalar service. |
| Gamma older 5191177… | Researcher pinned historical source | Different whitelist/rebalance behavior; not interchangeable with master. |
| Range Protocol V3 | Researcher full vault source | C exact-share basket funding, manager-sized swaps, two-token exit; special one-leg domains only. |
| Bunni V2 / V4 | Hub/logic/quoter/rebalance researcher trace; README moderator read | C after positive two-leg initialization; conditional queues; manager unlock paths. Project warns against production use as-is. |
| Uniswap Labs DualPool / PoolVault | Pinned researcher source; moderator official docs | C proportional two-token accounting; non-transferable internal shares, conditional deposit locks, unlock-based withdrawal. Not SE/SY fungible shares. |
| DeFiEdge strategies | Official documentation/indexed whitepaper | Positive lead for local unilateral oracle-valued admission; complete Solidity/formula/license not closed. |
| Steer Smart Pools / SDK | Documentation/examples and researcher excerpts | Supplied strategy amounts/SDK planning leads; example placeholders are not production evidence. |
| Revert Auto-Range / compounder / Lend | Documentation, researcher version distinctions | NFT automation/lending are not common LP-share admission; scalar UX conversion must be traced separately. |
| Mellow legacy UniV3 Boosted / newer queues | Documentation-led | Buffer+CL architecture useful; synchronous user flow not closed; newer queued products cannot stand in for synchronous SE. |
| Sommelier / Popsicle / ALPS | Lighter researcher evidence | Discovered management/proportional/valuation leads; not promoted to complete source-verified solutions. |
| ICHI oneToken / MintMaster | Separate product documentation | Not ICHIVault CL admission. Its collateral/oracle/controller claims cannot be transferred to the vault. |
| libevm single-sided helper | Primary author article / researcher library trace | Explicit off-chain binary-search approach; negative comparator, not evidence no analytic solution exists. |
| Official Uniswap SDK routeToRatio | Moderator primary search result | Explicit maxIterations and generated transaction calldata; useful UX, not autonomous on-chain sizing. |
| Panoptic / EulerSwap / range-order primitives | Discovery-level related designs | Different economic products; no complete analogue established. |
| ZapVault (joaoolucas) | Moderator-discovered README only | V4 scalar USDC UX but per-user positions and explicit unlock; no fungible common-book/source-safety proof. Not a new verified match. |

Not every candidate on the initial lead list was source-closed. Sorella/Angstrom, further V4 vaults and several light rows remain coverage gaps. Failure to fetch guessed paths was recorded, not converted into absence of a design.

## 3. Aperture: strongest positive no-binary-search mechanism

**Source:** [OptimalSwap at c40aaa98cf49baf454fbb7a8ee6709862e27038e](https://raw.githubusercontent.com/Aperture-Finance/uniswap-v3-automan/c40aaa98cf49baf454fbb7a8ee6709862e27038e/src/libraries/OptimalSwap.sol).

The research traced `mintOptimal` / `increaseLiquidityOptimal` through `_optimalSwap` and `_optimalSwapWithPool`. Empty `swapData` selects direct on-chain calculation rather than an aggregator-supplied amount. Fee deductions and unused-asset refunds are explicit. The moderator directly verified `getOptimalSwap`, `crossTicks`, `solveOptimalZeroForOne`, `solveOptimalOneForZero` and their state fields.

Algorithm:

1. Read pool price, active liquidity, fee, desired tokens and target range.
2. Move through initialized tick segments until available amounts cannot reach the next segment or the optimal direction changes.
3. Solve analytically within the final constant-liquidity segment.
4. Execute the sized swap and provide liquidity.

The general walk is `do … while(true)` with no explicit application step cap identified in this function. Its purpose is to locate the segment containing the desired amount, not merely execute an amount already known. Therefore:

| Requirement | Verdict |
|---|---|
| Avoid binary search over candidate swap amounts | **Yes, genuine implementation precedent.** |
| Avoid repeated whole-path trial quotes | Different structure: one progressing segment walk plus terminal solve; comparative gas unmeasured here. |
| Avoid all sizing discovery | **No** for the general algorithm. |
| Solve a certified single initial segment once | Plausible restricted reuse; exact acceptance/liveness proof still needed. |
| Directly solve existing Hookless whole-book ownership | **No**, not as written. |

For continuous interior token0-in math, let s/t be initial/final sqrt price, [a,b] target range, L active liquidity, x/y caller inventories, and g=1−f. The solve enforces:

```
x' = x - L*(1/t - 1/s)/g
y' = y + L*(s-t)
x'/(1/t - 1/b) = y'/(t-a)
```

That reduces to a quadratic. The code has Q96 rounding, approximations and clamps; the continuous equation is not a replacement integer specification.

Crucially, its state has no arbitrary incumbent local F, earned E, share supply, multiple owned ranges or own-LP fee attribution. Hookless instead needs a contribution aligned to the repriced **complete incumbent book**, if that ownership law is retained. Adapting the equation is work—not grounds to dismiss it, nor grounds to copy it unchanged. Fresh-deposit conversion is genuinely supported by Automan; MiniMax's review statement that it is only useful for known-output/rebalance is too narrow.

The scalar-target withdrawal path collects known position assets then swaps the opposing amount, checks a target minimum and refunds residuals. That reinforces our known-share/proportional-realization exit direction. NFT custody, token residuals and fee policy differ from the required vault; it is not “reusable as-is.”

## 4. ICHI: concrete alternative to internal-CP admission

**Primary source:** [verified Celo ICHIVault 0x07fddb65631529df92e87e536aa9aeec8ba1d020](https://celoscan.io/address/0x07fddb65631529df92e87e536aa9aeec8ba1d020). Direct explorer capture was incomplete in researcher passes; both Astra and moderator retrieved substantial source-function excerpts indexed from this primary page. This is indexed verified-source evidence, not a complete archived runtime attestation.

Let P=spot, T=TWAP, Z=source precision, B=pre-deposit totals and S=supply:

```
Plo = min(P,T); Phi = max(P,T)
depositValue = c1 + floor(c0*Plo/Z)
bookValue = B1 + floor(B0*Phi/Z)
minted = floor(S*depositValue/bookValue)    // live supply
```

Bootstrap uses depositValue directly in this source; **our dual activation/dead-sink law is not replaced by that precedent**. The function checks enabled token sides, positive input, strict deposit maxima, recipient and post-mint total-supply cap. It pulls the deposit and mints without finding a conversion swap.

**Plain-English lesson:** value the incoming contribution conservatively and the old book conservatively in the opposite direction. When spot equals TWAP, this reduces to direct value-based admission; it does not impose the size-dependent virtual-CP price impact discussed previously. For an idealized $100+$100 book with 100 shares, a $100 contribution at unchanged equal prices would mint 50 shares before source-specific rounding/fees/gates, rather than approximately 41.42 under internal CP. That avoids that particular discount but shifts the problem to valuation accuracy and inventory-risk control.

When P differs from T, issuance discounts can be material. This is not a guarantee of fair external realization, and same-pool TWAP is not an independent oracle.

**Important gate correction:**

```
delta = abs(P-T)*Z/max(P,T)
if delta > hysteresis: require(checkHysteresis())
checkHysteresis(): latestObservation.blockTimestamp != block.timestamp
```

This is **not** a hard maximum allowed spot/TWAP deviation. Large deviation can pass the timestamp test. Do not call it a proved manipulation bound or copy it as our complete security policy. Default/configured side and size/supply caps also matter. Source comments describe inventory risk; comments about repeated-call gas deterring abuse are not economic proof.

The inspected withdrawal returns proportional token0 and token1 from local holdings/base/limit. The official SDK agrees. Scalar exit and our already-unlocked local settlement still need a design. The base deposit signature does not contain our required share-minimum argument; wrapper ABI leads exist but enforcement/funding closure remains incomplete.

**Derived opportunity, not an existing source API:** at frozen valid prices/book/supply, requested m shares requires `v=ceil(m*bookValue/S)`. Token0 input is `ceil(v*Z/Plo)` and token1 input v. This can support direct exact-share input sizing after domain/minimum/credit rules are specified. It does not invert an external swap or changing rate-provider target.

ICHI oneToken/MintMaster is a different product. It was conflated in MiniMax's original and is not evidence for this formula. Kimi's review left the formula unverified in its own fetches; the moderator's indexed primary verification closes that particular evidence gap, not the full source/license gate.

## 5. Beefy and Charm: strongest wing-management precedents

### Beefy CLM

[Pinned audit-submitted BeefyVaultConcLiq](https://raw.githubusercontent.com/sherlock-audit/2024-05-beefy-cowcentrated-liquidity-manager/42ef5f0eac1bc954e888cf5bfb85cbf24c08ec76/cowcentrated-contracts/contracts/vault/BeefyVaultConcLiq.sol), with matching strategy traced by researchers.

`_getTokensRequired` accepts the value-underweight side up to its deficit, then requires complementary value. It does **not** generically absorb unlimited input of either side. At live supply, the accepted contribution uses:

`m=floor(S*(c1+floor(c0*P/10^36))/(B1+ceil(B0*P/10^36)))`.

P is strategy spot price. Accounting excludes strategy-defined locked profits/pending fee amounts; it is not a drop-in replacement for our B=D+F+E definition. `deposit` calls `beforeAction` to remove positions for accounting, measures actual transfers and redeploys. `withdraw` returns both currencies. The main+alt strategy places feasible main liquidity, then residual one-sided liquidity, without a repair swap.

The [official CLM documentation](https://docs.beefy.finance/beefy-products/clm), page labeled August 2024, explicitly describes:

- main plus one-sided alt placement;
- deficit-side admission and aggregator zaps for arbitrary single-token UX;
- an imbalance swap fee paid to incumbents, described as capped at half the pool fee;
- basket core withdrawal, with aggregator conversion for a chosen token.

The later-described imbalance fee is **not implemented in the pinned earlier vault snapshot**. It is a useful policy precedent, not verified current fee code. Neither audit submission nor the presence of audit links proves the chosen source is current deployed bytecode or secure. Documentation assertions about IL avoidance/fully active capital are not adopted as proven financial claims.

### Charm Alpha

[AlphaStrategy](https://raw.githubusercontent.com/charmfinance/alpha-vaults-contracts/main/contracts/AlphaStrategy.sol) directly computes spacing-rounded base/bid/ask ranges, checks TWAP deviation and calls:

`vault.rebalance(0, 0, baseLower, baseUpper, bidLower, bidUpper, askLower, askUpper)`.

The first zero is swap amount; the second is its price limit. **This supplied strategy intentionally performs no rebalance swap.** The vault removes base/limit, fills the base and uses residuals for one limit range. The manager can trigger/time it but does not provide a searched amount to this strategy.

This is the clearest correction to our earlier treatment of Charm: an ABI permitting a supplied swap amount does not mean its actual strategy requires one. Range selection is computed on-chain. However, its deposits/withdrawals are proportional baskets, and the strategy is keeper-controlled. Reuse the placement idea, not its admission or permissions unchanged. Alpha Pro is a separate configurable-weight product, not the same source.

**Combined lesson:** bounded shared core/wing placement is not novel speculation. It still must be paired with our required scalar admission/exit policy, sleeve reservation and permissionless-management law.

## 6. Arrakis: fixed arithmetic plus honest residual handling

[RouterSwapResolver.calculateSwapAmount](https://raw.githubusercontent.com/ArrakisFinance/v2-periphery/main/contracts/RouterSwapResolver.sol) reads inventory, accepts a price and computes a split without search. For scalar token0 c, continuous normalized `w=B0/B1`, token1-per-token0 P:

`swapAmount = c/(1+w*P)`.

The actual integer code normalizes decimals, uses floors and subtracts already-matchable basket amounts. Its `10^(18-decimals)` assumption is not automatically compatible with every local metadata domain.

The current router/executor still receives `amountInSwap`, router and payload from the caller. After actual execution it determines a feasible basket and returns leftovers. **Two distinct observations are both true:** a direct on-chain estimator exists; the current scalar execution interface is not autonomous from only a token and amount.

The estimate does not solve exact fee-inclusive post-swap incumbent alignment. Its residual/refund policy tolerates that. An autonomous adapter with a fixed supported route could reuse the structure, but acceptance loss/minimums and residual ownership must be explicitly defined. Current Hookless exact-in credits/retains all input and does not refund; do not silently import the foreign semantics or drop the 1 bp constraint.

Arrakis core also accounts for per-position rounded liquidity debts in exact-share minting. “Just multiply rounded total reserves by share ratio” is not always exact settlement parity.

## 7. Why Gamma, Bunni and DualPool are not the missing complete vault

**Gamma:** spot-value minting is genuine, but the entire admission path matters. [ClearingV2.clearDeposit](https://raw.githubusercontent.com/GammaStrategies/hypervisor/master/contracts/ClearingV2.sol) normally requires both amounts positive and two ratio checks; `freeDepositList` is a privileged bypass. Spot-in-base-range, pause, registration and configurable TWAP checks also apply. UniProxy validates and forwards; it is not itself the swapper several originals assumed. Older public-deposit and later whitelisted versions must remain separate. This is valuable valuation/gating evidence, not universal arbitrary scalar admission.

**Bunni V2:** existing positive two-leg deposits are proportional; zero-book LDF and one-sided reserve cases are distinct domains. Withdrawal combines proportional raw holdings and external reserve shares and returns both currencies; some configurations queue. Its management may size an order on-chain for later external filling—later execution is not automatically off-chain sizing. Ordinary unlock-dependent paths do not supply our sleeve-only nested behavior. The [repository README](https://raw.githubusercontent.com/Bunniapp/bunni-v2/main/README.md) explicitly warns the relevant issues are not addressed and not to use the code in production as-is. No exploit amount or causal narrative is asserted here.

**DualPool:** [official LP guide](https://developers.uniswap.org/llms.mdx/docs/protocols/uniswap-labs-hooks/dualpool/guides/provide-liquidity) and pinned sources describe requested-share proportional deposits and two-token withdrawals. Shares are **non-transferable internal entries, not ERC20 shares**. `minDepositBlocks=0` disables its optional lock; do not assume a universal same-block ban. Withdrawal opens PoolManager.unlock to redeem currency claims. The distinction between total economic assets and immediately realizable liquidity is useful, but virtual offsets, bootstrap policy, deposit locks, ownership permissions and JIT behavior cannot silently replace current SE law.

## 8. V3 reuse in V4: useful math, different execution

The common concentrated-liquidity amount equations make V3 designs relevant. Nonetheless:

- V3 core position key is owner/lower/upper; **no salt**. V4 adds salt within a pool. V3 NFT custody is a separate periphery layer.
- V3 uses pool-specific callbacks; V4 uses singleton PoolManager delta settlement and unlock sessions. A foreign V3 function does not literally call V4.unlock—MiniMax's review wording is incorrect.
- V4 fee/hook models, native currency, tick snapshots and settlement accounting must be modeled for the admitted integration. Pons stays separate from Hookless.
- `modifyLiquidity` caller delta includes principal plus fees; no double credit of informational fee returns.
- Multiple positions require correct bounded overlays, fee checkpoints and state projection; one-range analytic math cannot absorb them by treating all L as interchangeable.
- Our already-unlocked product path must price against full backing but spend only actual local cover. None of these inspected sources supplies that complete behavior for our integration.

Useful scalar exits were traced as known proportional removal followed by an already-sized opposing-token swap in Automan and a Blueberry wrapper lead. This is a positive mechanism, **not** proof every exit everywhere uses it, nor a ready-to-copy blocked-state implementation. Preserve meaningful minOut/maxIn/deadlines, source-agnostic pretransfer, complete booking and current residual policy unless expressly amended.

Direct scalar mint inverses may replace `_faceForClaim` and `_invertBufferForEffective` only with matching snapshot/rate semantics. Their eight interpolation attempts are not total probe limits. `zapSplitWad` remains a separate outer allocation search. No foreign vault automatically removes it. This matters to end-to-end performance/composability; it cannot be dismissed as out of scope while claiming a complete solution.

## 9. Attributed conclusions and moderator adjudication

| Researcher | Principal contribution | Corrections after cross-review |
|---|---|---|
| Astra | Pinned Aperture and Beefy traces; Arrakis estimator; Gamma Clearing; Charm zero-swap; later ICHI source excerpt and DualPool nontransferability | Narrowed claims to source versions, single-position vs whole-book, and discovery vs bisection. Ranks analytic and conservative-valuation mechanisms highly. |
| Grok replacement | Historical Gamma and Celo ICHI leads; Bunni/position-accounting distinctions | Added Aperture/Charm evidence, separates old/new Gamma. Prefers bounded management and remains cautious about whole-book solver adaptation. |
| MiniMax M3 | Broad candidate discovery and CLM/analytic leads | Withdrew class-A/full-scalar and several license/product conflations. Review still contains unsupported classifications and universal/gate claims; not adopted as authority. |
| Kimi K3 | Multi-stack comparison, DualPool and scalar-exit wrapper lead | Corrected Charm strategy and overbroad two-family taxonomy; emphasizes management reuse and valuation admission. Some source gaps remained attributed in its review. |

**Agreement:** useful wing management exists; scalar UI alone is not evidence; Aperture avoids binary search but general sizing discovers segments; no complete inspected drop-in is established. **Dissent:** priority of analytic adaptation versus valuation admission versus management reuse. The moderator selects a conditional two-track shortlist rather than treating a vote as proof.

Corrections that persist despite some reviews: ICHI hysteresis is not a hard deviation cap; Aperture has an autonomous empty-data path and is not merely off-chain planning; unknown licenses remain unknown rather than default BUSL; core basket exit is not “class A on withdrawal”; a manager parameter does not prove hidden search if its strategy sets zero; absence of a precedent does not prove uniqueness/nonexistence. Audit findings against lending-oracle consumers are not automatically vault-mint exploits. No “industry-proven safety” language is adopted.

## 10. Recommended next bounded question and acceptance gates

**First choice for mathematical follow-up:** Aperture's segment solver versus the current complete incumbent-book equation. Determine whether controlled accounting/placement separation can give an analytic solution with explicit owned-LP fee and rounding treatment. If strict no-discovery is retained, require a certified single-segment domain and truthful rejection; if no-binary-search is sufficient, study a bounded monotone walk without importing unlimited work. No gas benefit is asserted until measured.

**Parallel design alternative for strict search-free scalar service:** ICHI-style direct conservative valuation plus Charm/Beefy-style bounded management, with a separately specified idle proportional-conversion exit and blocked local settlement. Close source/wrapper/licensing, feed/risk policy, amount-dependent fee inversion and cross-mode economic analysis first. This is not approval to copy ICHI's timestamp heuristic or introduce setters/caps foreign to current law.

**Secondary alternative:** Arrakis-like fixed split plus actual-fill admission if the owner accepts changed residual/full-consumption semantics. Beefy deficit-only admission can be an optimization, not the sole mandatory scalar route.

The chosen specification must explicitly amend Hookless D1–8 admission/order/residuals, D17–21/D25 route/inverse/protection/management semantics and D27/D30 parity; retain D15–16 funding/booking, D22 family separation, dual activation/dead sink and current fixed bounds unless approved otherwise. Corresponding Orbital/SY/rate-provider obligations are not automatically satisfied by an SE change.

Later authorized validation: independent exact integer references; meaningful supported domains rather than universal rejection; own-LP fee and incumbent repricing attribution; multi-position/deployed/free/fee reconciliation; terminal and work-limit distinction; donations and cross-mode round trips including real pool costs; blocked-cover atomicity; stale/deviating observations; mixed decimals/extreme ticks; exact ordinary/transition/SY execution parity. Only afterward benchmark pinned complete nested calls under unchanged 31M/32M constraints. Foreign gas estimates are not local evidence. No execution was performed in this round.

## 11. Versions, licenses, local evidence and saved record

All evidence accessed **2026-10-03**. Raw web results lack tool-provided line numbers; exact file/function/commit is cited rather than fabricated lines. Local compatibility sources were read directly in the retained discussion and researcher passes:

- `docs/plans/UNISWAP_V4_STANDARD_EXCHANGE_PROPORTIONAL_ZAP_IN_PRD.md:28–58,118–206,398–450` and corresponding implementation plan:119–150,170–214.
- `contracts/vaults/standard/exchange/protocols/uniswap/v4/fullSpread/hookless/UniswapV4FullSpreadHooklessStandardExchangeVaultTransitionPlanner.sol:73–108`; `...PositionRepo.sol:9–22`; `...InventoryMath.sol:253–292`.
- `contracts/vaults/standard/sy/NativeStandardYieldTarget.sol:20–76`.
- Orbital `...ExitQuoteLib.sol:347–374`, `...ClaimLib.sol:250–276,315–329`, `...Math.sol:321–364`, co-located product PRD:828–835 and B6 PRD:35–43.
- `lib/crane/contracts/protocols/dexes/uniswap/v4/libraries/LiquidityAmounts.sol:19–76`, `SqrtPriceMath.sol:186–289`, quoter:46–50,69–80.
- `foundry.toml:29–36`: compiler 0.8.35, optimizer runs 1, via_ir=false. These settings are not a runtime/dependency commit attestation.

| Source/version | License/version evidence; not blanket legal clearance |
|---|---|
| Aperture c40aaa98cf49baf454fbb7a8ee6709862e27038e | OptimalSwap BUSL-1.1 header, pragma >=0.8.8. [Pinned LICENSE](https://raw.githubusercontent.com/Aperture-Finance/uniswap-v3-automan/c40aaa98cf49baf454fbb7a8ee6709862e27038e/LICENSE) specifies 2026-07-01 change date and GPL-2.0-or-later change license. Date has passed; version/dependency/combined-work obligations require review. Not MIT and not a blanket permanent copy ban. |
| Beefy audit snapshot 42ef5f0eac1bc954e888cf5bfb85cbf24c08ec76 | Inspected vault/strategy MIT, 0.8.23. Not a deployed revision attestation or current fee implementation. |
| Charm Alpha main | Unlicense, 0.7.6 for inspected files. Alpha Pro separately unclosed. |
| Arrakis V2 core/periphery main | Core BUSL-1.1; inspected resolver/executor UNLICENSED; 0.8.13. V1 unknown remains unknown. |
| Gamma master v1.3/v1.2.3/Clearing 2.0.0 | BUSL-1.1, 0.7.6; old 519117704a67659273b78658ad43bcad8a8073ce is a distinct source revision. |
| ICHI Celo source excerpts | Address/version-specific partial verified-source evidence; full license/runtime/wrapper closure open. |
| DualPool 5a584527d3026bb3b401a902ff0c4f4526b389c5 | Researcher fetched files MIT/0.8.26; docs confirm nontransferable ledger. Not ordinary ERC20 SE shares. |
| Bunni moving main | Inspected files MIT, some repository files AGPL; explicit production warning. No safe-copy conclusion. |

Additional primary leads: [official Uniswap swap-and-add guide](https://developers.uniswap.org/docs/sdks/v3/guides/managing-liquidity/swap-and-add), [libevm author article](https://www.libevm.com/2022/04/06/uniswapv3-optimal-single-lp/), [ICHI SDK](https://raw.githubusercontent.com/ichidao/ichi-vaults-sdk/main/README.md), [DeFiEdge docs](https://learn.defiedge.io/), [ZapVault README-only lead](https://github.com/joaoolucas/zapvault). Search snippets are labeled as such; instructions embedded in fetched pages were treated as untrusted content and not followed.

Confidence: high in directly fetched mechanism/permission/loop classifications; medium in their adaptability; unresolved in complete scalar economic safety, exact integer liveness, supported deployment versions and comparative gas. Breadth of search is not exhaustive proof.

### Retained sessions and artifacts

| Researcher | Session | Files in this directory |
|---|---|---|
| Astra | `ses_efedceddcffePvMhXHALsysYwr` | `astra-original.md`, `astra-cross-review.md` |
| Grok replacement | `ses_efe9c85c1ffexasWfYk2bT5JP0` | `grok-replacement-original.md`, `grok-replacement-cross-review.md` |
| MiniMax M3 | `ses_efd10d9aeffeZrzk3843SZFPTL` | `minimax-original.md`, `minimax-cross-review.md` |
| Kimi K3 | `ses_efd0301b6ffeRJ1euc9LP87byl` | `kimi-original.md`, `kimi-cross-review.md` |

Eight synchronous continuation calls completed this round. Historical replaced Grok was not resumed. The prior round's MiniMax write denial concerned a different artifact; this round's assigned original and review were successfully written. No substitutes, shell/tests/deployments/config changes or implementation occurred.

**Human checkpoint / separate implementation handoff:** choose whether a bounded analytic tick-segment walk satisfies the objective, or retain strict no-discovery and prioritize direct valuation or fixed-split semantics. Authorize a specific proof/port specification next, not execution by implication. This report and its source shortlist are the handoff; stop here.
