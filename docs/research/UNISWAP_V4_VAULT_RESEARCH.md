# Uniswap V4 Vault Research

**Date:** 2026-10-03  
**Author:** Astra moderator, consolidating the Astra / Grok / MiniMax M3 / Kimi K3 research council  
**Status:** External precedent findings recorded; the subsequent Aperture feasibility round is linked in §15. No adoption, implementation, deployment, or benchmark is authorized or claimed by this document.

## 1. Purpose and requirements

Identify existing Uniswap V3 and V4 vault and liquidity-management designs that can inform a Standard Exchange vault with efficient on-chain sizing.

The human's essential requirements are:

- Synchronous **single-token deposits and single-token withdrawals** remain supported. Basket-only and asynchronous-only replacements are unacceptable.
- The vault must remain useful inside an autonomous buffered pool, including its SE/SY and Orbital composition surfaces.
- Avoid expensive binary-search sizing. Distinguish that objective from the stronger requirement of eliminating every sizing-discovery traversal.
- Do not relocate required sizing into a router, keeper, backend, or off-chain payload that an autonomous caller cannot supply.
- Retain complete backing and fee ownership, meaningful execution protections, and a useful local liquidity sleeve.
- Already-unlocked PoolManager operations must respect the existing no-nested-unlock and actual-local-cover rules. No unlimited blocked-withdrawal promise.
- Full-range-only deployment may be reconsidered. One-sided out-of-range wings and later consolidation into a common core are permitted design investigations.
- Preserve separate Hookless and Pons Family V2 orchestration and fee models.

These are research constraints. Existing product PRDs remain authoritative until explicit amendments are approved. Selecting Aperture for investigation does not itself settle whether its tick-segment discovery is acceptable in the final product.

## 2. Executive findings

**Existing projects provide real reusable mechanisms.** In particular, Aperture implements on-chain analytic optimal-swap sizing without binary search. The prior discussion should not be read as establishing that unilateral deposits necessarily require binary search or internal constant-product admission.

| Lead | Verified useful mechanism | Main limitation |
|---|---|---|
| **Aperture OptimalSwap** | On-chain piecewise analytic sizing that accounts for swap-induced price movement | General path discovers the terminal tick segment; targets one position, not our complete incumbent book |
| **ICHI Vault** | Direct scalar share issuance using conservative spot/TWAP marks | Core withdrawal returns both currencies; protection, wrapper, and valuation-policy gaps remain |
| **Charm Alpha** | On-chain range calculation and deliberately zero-swap base/limit management | Basket admission/exit; keeper-controlled management |
| **Beefy CLM** | Main/alt placement and direct deficit-side scalar admission | Restricted side/amount; basket core exit; later documented fees differ from inspected snapshot |
| **Arrakis V2** | Arithmetic split estimator with post-fill basket accounting and residual handling | Current executor takes supplied router data; estimate does not guarantee exact whole-book alignment |

**No inspected stack was verified as a complete drop-in** combining fungible common-book shares, both scalar directions, strict no-sizing-discovery, our complete fee/backing semantics, and same-manager already-unlocked local-cover operation. This is a bounded search result, not a proof of nonexistence.

The strongest paths are:

1. Investigate **Aperture's analytic sizing** as an alternative to repeated whole-path trial simulations.
2. Keep **ICHI-style direct valuation admission** as a comparator if strict no-discovery is required.
3. Use **Charm/Beefy bounded core-and-wing management** as placement precedents independently of share admission.
4. Consider **Arrakis-style fixed splitting and explicit residuals** only if the corresponding consumption/refund changes are acceptable.

## 3. Aperture OptimalSwap — selected next investigation

### 3.1 Source and inspected revision

- Repository: <https://github.com/Aperture-Finance/uniswap-v3-automan>
- Commit: `c40aaa98cf49baf454fbb7a8ee6709862e27038e`
- [Pinned OptimalSwap.sol](https://raw.githubusercontent.com/Aperture-Finance/uniswap-v3-automan/c40aaa98cf49baf454fbb7a8ee6709862e27038e/src/libraries/OptimalSwap.sol)
- [Pinned LICENSE](https://raw.githubusercontent.com/Aperture-Finance/uniswap-v3-automan/c40aaa98cf49baf454fbb7a8ee6709862e27038e/LICENSE)

The council traced `mintOptimal` and `increaseLiquidityOptimal` through `_optimalSwap` and `_optimalSwapWithPool`. With empty `swapData`, the process computes the swap on-chain and executes directly against the pool. Aggregator calldata is an optional alternative, not a mandatory source of sizing on that path.

### 3.2 How it works

1. Read current sqrt price, active liquidity, fee, target range, and available token amounts.
2. Progress through initialized tick segments until remaining input cannot reach the next segment or the optimal direction changes.
3. Solve the final constant-liquidity segment analytically.
4. Execute the calculated swap and provide liquidity; handle unused assets explicitly.

The key functions are `getOptimalSwap`, `crossTicks`, `solveOptimalZeroForOne`, and `solveOptimalOneForZero`.

**The distinction matters:**

| Claim | Research verdict |
|---|---|
| No binary search over candidate input amounts | Supported by inspected code |
| General operation is one formula with no traversal | False: `crossTicks` discovers the final segment |
| Tick walk merely executes an already-sized swap | False: it participates in choosing the size |
| Explicit application step cap in the inspected `crossTicks` | Not identified; source uses `do … while(true)` |
| Terminal solver could inform a bounded or single-segment variant | Promising, not yet verified for our accounting |
| Lower gas in our nested vault calls | Unmeasured; no claim |

### 3.3 Mathematical target

For a continuous interior token0-in segment, let:

- s and t be initial and final sqrt prices;
- a and b be position endpoints;
- L be active pool liquidity;
- x and y be available token0 and token1;
- g=1−f be the fee complement.

The target is:

```
x' = x - L*(1/t - 1/s)/g
y' = y + L*(s-t)
x'/(1/t - 1/b) = y'/(t-a)
```

This yields a quadratic. The implementation uses Q96 arithmetic, rounding, approximations and clamps. The continuous expression is explanatory, **not an exact integer replacement specification**.

### 3.4 Why it is not yet a drop-in vault solver

The solver targets the token composition needed for one position. It does not itself account for:

- arbitrary incumbent local inventory F;
- earned uncollected fees E;
- fungible vault share supply;
- multiple owned positions with different ranges;
- attribution of the swap's repricing and own-LP fee recovery to incumbents;
- our retained-input/residual and placement-loss rules.

The current Hookless proportional admission rule targets the **post-swap complete incumbent book**, not simply the position's required token ratio. Adaptation must either derive that larger problem or explicitly change the accounting model. Wrapping the NFT result in ERC20 shares does not resolve it.

Aperture's scalar-target withdrawal path also provides useful evidence: collect known position assets, swap the opposing amount, check a target minimum and return residuals. This supports the known-entitlement conversion approach, but its NFT custody, fees and residual semantics require adaptation.

### 3.5 License boundary

The inspected source has a BUSL-1.1 header. Its pinned license specifies a **2026-07-01 change date** and **GPL-2.0-or-later change license**. That date has passed as of this research. Verify applicability to the selected version, dependencies and combined work before source reuse. It is not MIT, and the source header alone is not a complete current license analysis.

## 4. ICHI Vault — direct scalar valuation without a composition swap

Primary evidence: [Celo verified-source page, 0x07fddb65631529df92e87e536aa9aeec8ba1d020](https://celoscan.io/address/0x07fddb65631529df92e87e536aa9aeec8ba1d020) and [official vault SDK](https://raw.githubusercontent.com/ichidao/ichi-vaults-sdk/main/README.md).

The formula was recovered from indexed function bodies on that primary verified-source page. This is stronger than marketing documentation, but not complete source/archive/runtime/wrapper closure.

For spot P, TWAP T, source precision Z, pre-deposit holdings B and live supply S:

```
Plo = min(P,T)
Phi = max(P,T)
depositValue = c1 + floor(c0*Plo/Z)
bookValue = B1 + floor(B0*Phi/Z)
minted = floor(S*depositValue/bookValue)
```

Deposit admission checks enabled sides, positive contribution, per-side maxima, recipient and total-supply cap. It does not search for an external conversion amount.

**Relation to the internal-CP discussion:** when spot equals TWAP, this becomes value-based issuance rather than a size-dependent internal constant-product discount. For an idealized $200 book with 100 shares and a $100 contribution at unchanged reference prices, the value-based result is 50 shares, versus approximately 41.42 under the previously discussed uncharged internal CP model. This removes that particular curve discount but does not remove inventory or valuation risk.

### Hysteresis is not a hard price-deviation cap

The inspected code uses:

```
delta = abs(P-T)*Z/max(P,T)
if delta > hysteresis: require(checkHysteresis())
checkHysteresis(): latestObservation.blockTimestamp != block.timestamp
```

Large deviations can pass the timestamp check. It is not an independent oracle, a hard spot/TWAP bound, or a proof against manipulation. Caps and side permissions are additional controls. Do not copy the heuristic and claim economic safety.

Core withdrawal returns both currencies. A single-token exit, meaningful share minimum, and same-manager local-cover route still need to be specified for our product. ICHI oneToken/MintMaster is a separate product and must not be used as evidence for this CL-vault formula.

A direct exact-share input inverse can be derived at a frozen valid snapshot: `v=ceil(m*bookValue/S)`, then token0 input `ceil(v*Z/Plo)` or token1 input v. That is a derivation opportunity, not a verified existing API or an inverse of a swap-bearing exit.

## 5. Core and wing precedents

### 5.1 Charm Alpha

[AlphaStrategy.sol](https://raw.githubusercontent.com/charmfinance/alpha-vaults-contracts/main/contracts/AlphaStrategy.sol) computes spacing-rounded base/bid/ask ranges, checks TWAP deviation and calls:

```
vault.rebalance(0, 0, baseLower, baseUpper,
                bidLower, bidUpper, askLower, askUpper)
```

The first zero is swap amount and the second is its price limit. The supplied strategy intentionally performs **no rebalance swap**. The vault fills the base range and uses residuals for a single-sided limit range.

This is a concrete bounded wing-management precedent. A keeper triggers the operation, but does not supply a searched swap size to this strategy. The vault's ABI permitting a swap does not mean this strategy requires one.

Limitations: proportional basket admission and exit; keeper/governance permissions; moving-main source rather than deployment pin. Alpha Pro is a different product with configurable full-range/base/limit weighting. Neither is inherently full-range-only.

### 5.2 Beefy CLM

- [Pinned BeefyVaultConcLiq audit snapshot](https://raw.githubusercontent.com/sherlock-audit/2024-05-beefy-cowcentrated-liquidity-manager/42ef5f0eac1bc954e888cf5bfb85cbf24c08ec76/cowcentrated-contracts/contracts/vault/BeefyVaultConcLiq.sol)
- [Matching Uniswap strategy](https://raw.githubusercontent.com/sherlock-audit/2024-05-beefy-cowcentrated-liquidity-manager/42ef5f0eac1bc954e888cf5bfb85cbf24c08ec76/cowcentrated-contracts/contracts/strategies/uniswap/StrategyPassiveManagerUniswap.sol)
- [Official CLM documentation](https://docs.beefy.finance/beefy-products/clm)

The strategy uses a main position and one-sided alt. The inspected vault's `_getTokensRequired` algebraically accepts the underweight side up to its deficit, then requires complementary value. It does not provide unrestricted scalar admission of either token.

For accepted c, live-supply minting is:

`m=floor(S*(c1+floor(c0*P/10^36))/(B1+ceil(B0*P/10^36)))`.

P is strategy spot price. Strategy-defined locked profits and fee exclusions differ from our complete-book accounting. User operations remove/redeploy positions for accounting; this is not directly usable during our already-unlocked sleeve-only path. Core withdrawal pays both tokens.

Later official documentation describes an imbalance fee paid to incumbents, capped in that description at half the pool fee, and aggregator zaps for general scalar entry/exit. **That fee is absent from the inspected earlier snapshot.** Preserve the version distinction. Audit submission and linked audits do not prove current deployed equivalence or safety.

### 5.3 Lesson for our wing proposal

Core-plus-one-sided inventory placement has concrete precedents. It should remain separate from admission pricing. A mixed or fully crossed wing need not match the core ratio: add the feasible amount, retain and book residuals. Out-of-range liquidity is not immediately spendable cover while manager interaction is unavailable. Foreign keeper controls or cooldowns cannot silently replace our permissionless-maintenance law.

## 6. Arrakis V2 — direct split with actual-fill accounting

[RouterSwapResolver.calculateSwapAmount](https://raw.githubusercontent.com/ArrakisFinance/v2-periphery/main/contracts/RouterSwapResolver.sol) computes a split without binary search using current inventory and a supplied price. For scalar token0 input c, normalized inventory ratio w=B0/B1 and token1-per-token0 price P:

`swapAmount = c/(1+w*P)`

is the continuous simplified form. The actual code uses floors and decimal normalization, including assumptions that need checking for our token domains.

The current router/executor receives an amount, router address and payload from the caller. It then admits a feasible basket from actual received assets and returns leftovers. Thus:

- A direct arithmetic sizing estimator really exists.
- The existing complete interface is not autonomous from only a scalar input.
- The estimator does not prove fee-inclusive post-swap whole-book alignment.
- Residual handling makes approximate splitting workable, but differs from our exact-in retain-and-credit/no-refund law.

This is a design alternative if the owner approves changed consumption/residual semantics. It is not an excuse to silently weaken alignment or minimum-output protection.

## 7. Other candidates and disqualifiers

| Candidate | Finding | Why it is not the complete solution |
|---|---|---|
| Gamma Hypervisor / UniProxy / ClearingV2 | Direct spot-value mint formula | Normal Clearing path requires both deposits and ratio bands; scalar bypass is privileged. UniProxy is not itself a swapper. |
| Bunni V2 | V4 liquidity-density, raw/external-reserve accounting | Ongoing two-leg deposits are proportional, exits return both tokens, some configurations queue; unlock-dependent. Repository warns against production use as-is. |
| Uniswap Labs DualPool / PoolVault | V4 proportional share accounting and separation of economic assets from realizable liquidity | Shares are non-transferable internal entries, not ERC20 SE/SY shares; two-token routes and unlock-based exits. Optional deposit lock may be zero. |
| Range Protocol V3 | Requested-share basket funding and proportional exits | General scalar conversion is not supplied by the core; manager-sized swaps remain. |
| DeFiEdge | Documented local unilateral oracle-valued admission | Full source/formula/license not closed in this round. |
| Steer | SDK and managed-pool leads | Supplied strategy amounts/SDK planning need separation from autonomous user sizing. |
| Revert Auto-Range / compounder / Lend | NFT automation/lending and conversion leads | Different custody/economic products; not established common-book scalar admission. |
| Mellow / Sommelier / Popsicle / ALPS | Additional buffer, management, proportional or valuation patterns | Evidence depth varied; not promoted to complete source-verified matches. |
| libevm single-sided helper | Explicit binary-search approach intended off-chain | A negative comparator, not proof that an analytic solution does not exist. |
| Uniswap SDK `routeToRatio` | Iterative off-chain route preparation | Requires iterations and generated calldata; not autonomous on-chain sizing. |
| ZapVault | README describes V4 scalar USDC entry/exit | Per-user positions and explicit unlock; source/safety/fungible-book trace incomplete. |

Other discovered leads, including Panoptic, EulerSwap, further V4 hooks and range-order primitives, did not establish a complete analogue. The search was broad, not exhaustive proof.

Primary references for important exclusions:

- [Gamma ClearingV2](https://raw.githubusercontent.com/GammaStrategies/hypervisor/master/contracts/ClearingV2.sol)
- [Bunni repository warning](https://raw.githubusercontent.com/Bunniapp/bunni-v2/main/README.md)
- [DualPool liquidity guide](https://developers.uniswap.org/llms.mdx/docs/protocols/uniswap-labs-hooks/dualpool/guides/provide-liquidity)
- [Uniswap swap-and-add guide](https://developers.uniswap.org/docs/sdks/v3/guides/managing-liquidity/swap-and-add)
- [libevm author article](https://www.libevm.com/2022/04/06/uniswapv3-optimal-single-lp/)

## 8. V3-to-V4 reuse boundaries

The underlying concentrated-liquidity equations are closely related and make V3 precedents valuable. Execution and custody are not interchangeable:

1. **Position identity:** V3 core keys owner/lower/upper without salt; V4 adds salt within each pool. NFT custody is a separate periphery layer.
2. **Settlement:** V3 pool-specific callbacks must become correct V4 PoolManager unlock and currency-delta settlement. A function that opens its own unlock cannot be called unchanged inside an already-unlocked session.
3. **Fees:** model actual LP/protocol fees and admitted hook behavior. Own earned fees count once. PoolManager caller delta includes principal plus fees; its informational fee return is not a second cash inflow.
4. **Accounting:** preserve local custody snapshots separately from deployed principal and uncollected fees. Foreign profit locks and fee reserves are version-specific policies, not substitutes for `B=D+F+E`.
5. **Quotes:** multiple owned ranges require matching projected liquidity and fee changes. A single-range overlay or analytic ratio cannot silently represent a multi-position book.
6. **Interfaces:** preserve scalar SE/SY signatures, meaningful minima/maxima, deadlines and actual funding semantics. Foreign refund, pause, permission or lock policies need explicit approval.
7. **Pons:** no shared Hookless/Pons fee or execution dispatcher is authorized by mathematical reuse.

## 9. Orbital and already-unlocked behavior remain integration work

No inspected precedent supplied the complete combination of our scalar quote/execution semantics and same-manager local-cover behavior.

- Price claims against complete backing; pay blocked withdrawals only from actual local inventory. Uncollected fees and deployed positions are not local cover.
- Direct scalar mint inverses may replace `_faceForClaim` and `_invertBufferForEffective` only when snapshot and rate conventions match execution. A changing target rate can reintroduce an unsolved inverse.
- Eight interpolation attempts in those routines are not eight total probes; their bisection loops continue.
- `zapSplitWad` is a separate outer allocation search. Making an inner quote analytic does not eliminate it.
- Preserve configured shares-times-rate valuation and raw-share B6 liquidity accounting, rather than valuing held shares with a trade-sized SE quote or gas-dependent fallback.

The adoption study must distinguish a **Hookless optimization** from an **end-to-end search-free Orbital claim**. It must also distinguish known-share exact-input redemption from exact-output share sizing; an analytic deposit solver does not supply every inverse.

## 10. Corrections preserved from council review

- Aperture is a real on-chain conversion path, not merely off-chain planning; its general algorithm still discovers tick segments.
- ICHI's hysteresis heuristic is not a hard deviation cap, and ICHI Vault is not ICHI oneToken.
- Beefy's direct scalar domain is deficit-limited; its documented later charge must not be attributed to the earlier snapshot.
- Charm's supplied AlphaStrategy passes zero swap amount despite a more general vault ABI.
- Gamma must be assessed across Hypervisor, UniProxy and Clearing, not from the mint formula alone.
- DualPool shares are non-transferable; deposit locks are configurable, not universally mandatory.
- V3 core positions do not have V4's salt field.
- A scalar frontend button, deterministic placement, basket exit, audit label or popular deployment does not prove the full requested behavior or security.
- Failure to find a complete match does not establish nonexistence or uniqueness of internal CP.

Researchers differed on prioritization: Astra emphasized analytic sizing and conservative valuation, Grok favored bounded management and cautioned about whole-book adaptation, Kimi emphasized wing management and admission controls, and MiniMax broadened discovery but required material classification/license corrections. The recorded recommendation is an evidence-based shortlist, not a declaration of unanimous implementation readiness.

## 11. Source versions and license gates

All external findings were accessed on **2026-10-03**. Moving branches are not deployment pins. Exact functions and commits are cited where raw fetches did not provide reliable line numbers.

| Source | Recorded evidence |
|---|---|
| Aperture `c40aaa98cf49baf454fbb7a8ee6709862e27038e` | OptimalSwap pragma >=0.8.8, BUSL-1.1 header; pinned license changes to GPL-2.0-or-later on stated 2026-07-01 date. Review version/dependency obligations. |
| Beefy `42ef5f0eac1bc954e888cf5bfb85cbf24c08ec76` audit snapshot | Inspected vault/strategy MIT, Solidity 0.8.23; not current deployment attestation. |
| Charm Alpha main | Inspected files Unlicense, Solidity 0.7.6; Alpha Pro separately unclosed. |
| Arrakis V2 main | Core BUSL-1.1, inspected periphery UNLICENSED, Solidity 0.8.13. V1 license remains unverified. |
| Gamma master | Hypervisor v1.3, UniProxy v1.2.3, ClearingV2 2.0.0; inspected files BUSL-1.1/0.7.6. Historical `519117704a67659273b78658ad43bcad8a8073ce` is distinct. |
| ICHI Celo source | Address-specific indexed verified-source excerpts; full source/license/wrapper/runtime closure remains open. |
| DualPool `5a584527d3026bb3b401a902ff0c4f4526b389c5` | Researcher-inspected files MIT/0.8.26; transitive review still required. |
| Bunni main | Inspected files MIT; repository notes some AGPL files and warns against production use as-is. |

No legal clearance to copy source is implied. Neither blanket “permissive” nor blanket permanent “cannot copy” conclusions should replace version-specific review.

## 12. Next investigation: Aperture adoption feasibility

**The human selected Aperture OptimalSwap as the next exploration after this record is written. That exploration has not been executed by this documentation task.**

The follow-up should answer:

1. Can the terminal analytic equation account for our complete post-swap incumbent book, including F/E, finite-range principal and own-LP fees, or what accounting changes are necessary?
2. Can the progressing tick walk have a defensible work bound without introducing repeated trial simulations or unacceptable route failures?
3. Which exact integer rounding, overflow, tick-boundary and fee cases differ between the Aperture dependencies and current Crane V4 math?
4. Can deposit composition, placement and holder maintenance be separated while preserving required ownership and residual behavior?
5. How are scalar exits, blocked-state local settlement, exact-output eligibility, transition quotes and rate projection preserved?
6. Does the port support a full-range core, core-plus-wings, or both, and what multi-position state/overlay changes are required?
7. Which D1–D31 and corresponding Orbital/SY/DETF amendments are actually necessary?
8. What source reuse is permitted for the pinned version and its dependencies?
9. What independent correctness and later end-to-end benchmark evidence must precede adoption?

This is a research agenda, not a plan to implement or a decision to weaken protections. No gas improvement is established. No requirement for universal success in arbitrary liquidity states is invented; supported domains and truthful rejections must be explicit.

## 13. Local authority and evidence

Current authority remains `CLAUDE.md` and current task/family PRDs. Relevant local evidence, read during the retained research discussion:

- [`UNISWAP_V4_STANDARD_EXCHANGE_PROPORTIONAL_ZAP_IN_PRD.md`](../plans/UNISWAP_V4_STANDARD_EXCHANGE_PROPORTIONAL_ZAP_IN_PRD.md):28–58,118–206,398–450 — accepted decisions, backing, funding and booking.
- [`UNISWAP_V4_FULLSPREAD_IMPLEMENTATION_AND_TEST_PLAN.md`](../plans/UNISWAP_V4_FULLSPREAD_IMPLEMENTATION_AND_TEST_PLAN.md):119–150,170–214 — composition and route matrix.
- `contracts/vaults/standard/exchange/protocols/uniswap/v4/fullSpread/hookless/UniswapV4FullSpreadHooklessStandardExchangeVaultTransitionPlanner.sol:73–108` — current caller-composition search.
- Same Hookless prefix `PositionRepo.sol:9–22` and `InventoryMath.sol:253–292` — current position model and explicit placement loss.
- `contracts/vaults/standard/sy/NativeStandardYieldTarget.sol:20–76` — scalar aliases.
- Orbital `UniswapV4StandardExchangeOrbitalBufferHookExitQuoteLib.sol:347–374`, `...ClaimLib.sol:250–276,315–329`, `...Math.sol:321–364` — outer inversion/rate/split behavior, under `contracts/hooks/uniswap/v4/standardExchange/orbital/`.
- Orbital co-located product PRD:828–835 and B6 remediation PRD:35–43 — held-rate and raw-share liquidity law.
- `lib/crane/contracts/protocols/dexes/uniswap/v4/libraries/LiquidityAmounts.sol:19–76`, `SqrtPriceMath.sol:186–289`, `utils/UniswapV4Quoter.sol:46–50,69–80` — amount math, settlement rounding and current single-change overlay.
- `foundry.toml:29–36` — local Solidity 0.8.35, optimizer runs 1, via_ir=false. Configuration is not deployed-code attestation.

Later authorized validation must include independent integer references, incumbent fee/repricing ownership, actual local/deployed/earned reconciliation, supported-domain liveness, failed-cover rollback, donations and cross-mode cycles with real pool costs, and bit-exact ordinary/transition/SY parity. Only then measure pinned full nested transactions under unchanged 31M/32M constraints; foreign source comments or vendor measurements are not our benchmark.

## 14. Provenance and handoff

This standalone report records the completed external-precedent round. Detailed evidence, disagreements and access gaps remain in the immutable originals and reviews:

- [Complete council synthesis](uniswap-v3-v4-vault-precedents-2026-10-03/COUNCIL_SYNTHESIS.md)
- [Shared research question](uniswap-v3-v4-vault-precedents-2026-10-03/COUNCIL_QUESTION.md)
- [Astra original](uniswap-v3-v4-vault-precedents-2026-10-03/astra-original.md) / [cross-review](uniswap-v3-v4-vault-precedents-2026-10-03/astra-cross-review.md)
- [Grok replacement original](uniswap-v3-v4-vault-precedents-2026-10-03/grok-replacement-original.md) / [cross-review](uniswap-v3-v4-vault-precedents-2026-10-03/grok-replacement-cross-review.md)
- [MiniMax original](uniswap-v3-v4-vault-precedents-2026-10-03/minimax-original.md) / [cross-review](uniswap-v3-v4-vault-precedents-2026-10-03/minimax-cross-review.md)
- [Kimi original](uniswap-v3-v4-vault-precedents-2026-10-03/kimi-original.md) / [cross-review](uniswap-v3-v4-vault-precedents-2026-10-03/kimi-cross-review.md)

Retained sessions for follow-up:

| Researcher | Session |
|---|---|
| Astra | `ses_efedceddcffePvMhXHALsysYwr` |
| Grok replacement | `ses_efe9c85c1ffexasWfYk2bT5JP0` |
| MiniMax M3 | `ses_efd10d9aeffeZrzk3843SZFPTL` |
| Kimi K3 | `ses_efd0301b6ffeRJ1euc9LP87byl` |

Confidence is high in directly verified mechanism, permission and loop distinctions; medium in applicability; unresolved in whole-book adaptation, economic safety, exact integer liveness and measured performance. Agreement and passing tests are not proof of security.

**Implementation handoff:** documentation is complete. Aperture feasibility research is the next selected topic, not yet an approved implementation. No contracts, tests, configuration or instruction files were edited; no shell, tests, transactions, deployments or benchmarks were run for this authoring task.

## 15. Subsequent Aperture feasibility findings

The human subsequently authorized the selected investigation. Its completed report is [Aperture OptimalSwap: operation and V4 Hookless feasibility](aperture-v4-hookless-feasibility-2026-10-03/COUNCIL_SYNTHESIS.md). This addendum updates the research status; §12 preserves the original agenda rather than implying the follow-up has not occurred.

The new round traces the exact V3 money path and versioned bitmap dependency, distinguishes autonomous single-pool-token `mintOptimal` from arbitrary-third-token routing, and derives a **continuous fixed-segment whole-book quadratic** including arbitrary sleeve/prior fees, owned active liquidity and protocol-adjusted own LP recovery. Sleeves and multiple fixed-active-set positions do not inherently force a higher polynomial degree.

This materially strengthens feasibility of preserving current proportional ownership with an Aperture-inspired sizing planner. It is not an integer execution proof or existing V4 implementation. Word-step rounding, fee checkpoints, root/overflow handling, terminal placement loss, useful acceptance domains, settlement and bounded traversal remain gates. Current already-unlocked sleeve-only policy and outer Orbital inversions/`zapSplitWad` are not removed by a forward analytic solve.

All four retained sessions supplied originals and combined reviews. No implementation or measurements occurred. The next handoff is a bounded proof/port specification, subject to human authorization—not automatic code execution.

## 16. Owner-selected staged refactor PRD

The owner subsequently selected Aperture-inspired sizing for a refactor of the existing Hookless SE and required math-library implementation/tests before vault integration. The requirements are recorded in [UNISWAP_V4_HOOKLESS_APERTURE_OPTIMAL_SWAP_REFACTOR_PRD.md](../plans/UNISWAP_V4_HOOKLESS_APERTURE_OPTIMAL_SWAP_REFACTOR_PRD.md).

The PRD preserves proportional whole-book admission, single-token entry/exit, the sleeve and current protections. It establishes Stage 1, mandatory Gate M and Stage 2 integration. A detailed implementation plan remains future work. No code, tests or benchmarks have been executed by authoring these documents.
