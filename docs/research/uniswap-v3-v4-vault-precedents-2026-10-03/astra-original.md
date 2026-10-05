# Astra — online V3/V4 vault precedent search

**Access date: 2026-10-03. Independent original for this question.** Retained history acknowledged; no peer artifacts read. Public searches used only generic project/math terms. Research only: no tests, transactions, code execution, implementation or gas measurements. No consensus claim.

## 1. Findings that materially advance the investigation

**There are real reusable solutions to narrower parts of the problem.** Most importantly, Aperture implements an on-chain piecewise analytic optimal-swap algorithm, not just a frontend amount calculator. Arrakis publishes a direct arithmetic split estimator. Beefy demonstrates inventory-deficit admission and main-plus-one-sided-alt placement. These deserve examination rather than repeating that conversion necessarily requires binary search.

**I did not verify a complete drop-in precedent satisfying all requirements simultaneously:** fungible common-book shares; either scalar entry and scalar exit; strict absence of sizing discovery; arbitrary incumbent sleeve/fees; autonomous calls while the same V4 manager is already unlocked. This is a bounded search result, not nonexistence evidence.

The most important distinction discovered is between:

* **No binary search:** Aperture genuinely supplies a positive implementation precedent.
* **No sizing discovery:** Aperture's general path first walks ticks until the optimal direction reverses. That discovers the final segment before solving its quadratic. It is not simply traversal of an already-sized swap, so it does not automatically pass the stricter requirement.
* **No deposit swap:** ICHI documents genuine scalar deposits; Beefy admits a limited deficit-side scalar amount; neither fact establishes a fully scalar withdrawal core.

## 2. Coverage/classification ledger

Classes: **A** intrinsic deterministic scalar vault; **B** caller/SDK-supplied conversion; **C** basket core, possibly wrapped; **D** valuation/internal-inventory admission; **E** nonfungible/private/asynchronous/not analogous. Classes can overlap; “entry only” is not full A. Code findings below are observations; transferability is inference.

| Candidate/version | Evidence inspected | Classification and result |
|---|---|---|
| Aperture UniV3 Automan | Complete OptimalSwap, Automan, SwapRouter, README, license; main resolved to `c40aaa98cf49baf454fbb7a8ee6709862e27038e` | **E**, with genuine on-chain scalar conversion mechanism; optional **B** aggregator path. NFT, not fungible vault; tick-segment discovery remains. |
| Beefy CLM, May-2024 audit snapshot | Complete vault and Uniswap strategy at `42ef5f0eac1bc954e888cf5bfb85cbf24c08ec76`; official Aug-2024 product docs | **D** restricted deficit-side entry; **C/B** general UX; two-token withdrawal. Concrete wing/alt precedent. |
| Charm Alpha V3 | Complete AlphaVault and AlphaStrategy, main | **C**; local proportional entry, two-token exit; two ranges and deterministic no-swap strategy. |
| Charm Alpha Pro | Official AlphaProVault technical reference | **C**; separate rebalance, full-range/base/limit configuration. Distinct from Alpha; implementation not deeply traced. |
| Arrakis V2 core/periphery | Complete vault, Underlying, router, swap executor and split resolver | **C+B**; direct split estimator is reusable, but executor accepts swap amount/router payload. |
| Arrakis Modular public router | Indexed official router/public-vault documentation | **C+B**, provisional documentation-level; current fetched legacy URL redirects to Pro overview. Do not conflate with private Pro. |
| Arrakis Pro/current modular | Fresh official documentation | **E** issuer-owned NFT vault, off-chain strategy instructions; not public fungible scalar admission. |
| Gamma Hypervisor v1.3 / UniProxy v1.2.3 / ClearingV2 2.0.0 | Complete three contracts plus official integration docs | **D** spot-value mint internally, normally **C** admission enforced by Clearing; scalar bypass is privileged, not universal. |
| Range Protocol V3, master | Complete RangeProtocolVault | **C**, scalar only if book is already one-sided. Manager supplies swap amount; basket burn. |
| Bunni V2 / V4 | Complete Hub, HubLogic, Quoter, RebalanceLogic and repository warning | **C**, sometimes **E** queued withdrawal. Raw/ERC4626 reserve split is useful; not a scalar-vault solution. |
| ICHI Vaults / UniswapV3 SDK | Official SDK README and ICHI product materials; Solidity source access incomplete | Documented scalar entry, **D** valuation mechanism not verified here; SDK explicitly describes two-token withdrawals. Not full A. |
| DeFiEdge strategies | Official indexed whitepaper/litepaper and project article | Documented **D** scalar local-inventory admission with oracle gating; exact deployed/source formula unverified. |
| Steer Smart Pools / SingleAssetDeposit SDK | Official examples source and published package search evidence | **C/B** lead; staged calculate/simulate/prepare flow. Example source contains mock placeholders, so not production proof. |
| Mellow legacy UniV3 Boosted | Fresh official strategy/math documentation | Buffer+CL+yield architecture; user money path not source-closed. Not counted as demonstrated A. |
| Revert Lend V3Vault / Auto-Range context | Fresh official technical documentation | **E**: scalar lending vault with NFT collateral is not a fungible CL-asset admission solution. |

Thus **15 named/versioned candidates**, with full source tracing of six contract stacks plus Range as an additional source check. Documentation-only rows are deliberately not promoted to implementation evidence. Further discovered leads—BTR hybrid ERC4626/7540, ALPS keeper-managed vault, and Bonzo/ICHI scalar UX—remain unclosed, not extra successes.

## 3. Deep trace: Aperture — strongest positive algorithmic counterexample

Primary source prefix **AP**: `https://raw.githubusercontent.com/Aperture-Finance/uniswap-v3-automan/main/src/`.

Read `libraries/OptimalSwap.sol`, `base/SwapRouter.sol`, `base/Automan.sol`, `UniV3Automan.sol`. GitHub commits API resolved main to **c40aaa98cf49baf454fbb7a8ee6709862e27038e**; this is repository evidence, not deployment attestation.

**Money path:** `Automan.mintOptimal` pulls either/both pool tokens, deducts explicit token fee amounts subject to `feeConfig.feeLimitPips`, then `_optimalSwap`. With empty `swapData`, `_optimalSwapWithPool` calls `OptimalSwap.getOptimalSwap` on-chain, executes the returned exact-input amount, and mints an NFT. `_mint` refunds unused desired amounts. Existing positions use `increaseLiquidityOptimal`; `_reinvest` collects fees, deducts charges and follows the same optimizer. Controllers/owners supply rebalance ranges, but the empty-data inner swap amount is not backend-supplied.

**Algorithm:** `crossTicks` simulates a swap toward successive initialized ticks, checks whether resources suffice and whether `isZeroForOne` changes sign, then calls `solveOptimalZeroForOne` or its opposite. There is a `do ... while(true)` without an explicit application step cap. The final solve is a quadratic, with integer approximations/clamps in assembly—not a bisection over candidate amounts.

For token0→token1 within one constant-active-liquidity segment, normalize sqrt prices to real s, lower a, upper b; input inventories x,y; fee complement g=1−f; active liquidity L. The source's continuous coefficient interpretation is:

```
A = x + L/(g*s) − L/b
B = a*(x + L/(g*s)) + f*L/g − (y+L*s)/b
C = y + L*s − L*a/g
t = (B + sqrt(B²+4*A*C))/(2*A)
swapIn = L*(1/t−1/s)/g; swapOut = L*(s−t)
```

The actual source uses Q96 arithmetic and fee/amount rounding; these real equations are **not an exact integer replacement**. They target the contribution ratio for one range at final t. They do not contain arbitrary incumbent F/E, vault share supply, multiple ranges or incumbent own-fee attribution.

**Scalar exit:** `decreaseLiquidity`→`_decreaseLiquidity`→collect/deduct fees→`_swapRefund`. With selected tokenOut and empty corresponding swapData, it swaps the already-collected other token directly, checks `tokenOutMin`, and refunds remaining tokens. This is a genuine synchronous one-token-target realization mechanism, though residual non-target tokens can remain refunds and custody is NFT-specific.

**Reuse:** prioritize the terminal-segment solver, orientation logic and explicit no-aggregator path. To meet strict no-discovery, certify the initial segment and solve once, or obtain explicit owner acceptance of monotone tick-segment discovery. To handle Hookless, separately derive whole-book attribution; simply wrapping the NFT result in ERC20 shares is insufficient. V4 fees, exact-input sign, manager state and multi-position overlays require a port. Do not repeat the library comment's gas claims as measurements.

## 4. Deep trace: Beefy — useful deficit admission plus two-position management

Primary immutable source prefix **BF**: `https://raw.githubusercontent.com/sherlock-audit/2024-05-beefy-cowcentrated-liquidity-manager/42ef5f0eac1bc954e888cf5bfb85cbf24c08ec76/cowcentrated-contracts/contracts/`.

Read `vault/BeefyVaultConcLiq.sol` and `strategies/uniswap/StrategyPassiveManagerUniswap.sol`. This is an audit-submitted snapshot, **not proof of current deployed behavior**.

`deposit` calls `strategy.beforeAction`, which claims earnings and removes both positions. `_getTokensRequired` chooses accepted amounts algebraically. The vault pulls only those amounts directly to strategy, measures balance deltas, redeploys, then mints:

`m=floor(S*(c1+floor(c0*P/10^36))/(B1+ceil(B0*P/10^36)))` for live supply.

Here P is strategy spot price after its scaling path, and B uses strategy-defined balances. Those balances exclude locked profit and unharvested fee accounting; they are **not** our unqualified D+F+E book. Bootstrap subtracts 1,000 shares and mints them to the dead address.

**Positive scalar domain:** if token0 is underweight in value, `_getTokensRequired` can accept token0 alone up to the deficit. At a balanced book, an arbitrary scalar deposit is not accepted usefully; general entry uses zap tooling. This is a real alternative to demanding every deposit match the incumbent ratio, but not the required unrestricted direction/amount behavior.

`withdraw` removes all positions for accounting, computes both proportional amounts, sends them and redeploys the remainder. No scalar withdrawal in this core. `previewDeposit` and `previewWithdraw` expose arithmetic estimates; independent same-state parity is still an acceptance obligation, especially around pending-fee realization.

Strategy holds **main and alt**. `_setAltTick` chooses a lower token1 or upper token0 band from inventory value; `_addLiquidity` places main then residual alt without rebalancing swaps. `isCalm` compares spot tick against TWAP bounds; `rebalance` is restricted. Harvesting swaps only designated fee amounts to native, distributes configured fees, and streams retained profit.

Official [CLM docs](https://docs.beefy.finance/beefy-products/clm), dated August 2024, additionally describe an imbalance swap fee paid to incumbents, capped in that description at half the pool fee, and aggregator zaps on entry/exit. **That fee is not implemented in the earlier vault snapshot I read.** Do not combine later prose and earlier source into one supposedly verified fee formula. The concept—charge internal inventory absorption rather than offer it free—is worth reusing; exact current implementation remains a gap.

## 5. Deep trace: Arrakis V2 — direct split estimator, caller-supplied execution

Primary prefixes **AR**=`https://raw.githubusercontent.com/ArrakisFinance/v2-core/main/contracts/`, **ARP**=`https://raw.githubusercontent.com/ArrakisFinance/v2-periphery/main/contracts/`.

Read `ArrakisV2.sol`, `libraries/Underlying.sol`; periphery `ArrakisV2Router.sol`, `RouterSwapResolver.sol`, `RouterSwapExecutor.sol`.

The core accepts **requested shares m**, not an unpriced scalar contribution. For each range it adds `floor(L_j*m/S)` liquidity and charges exact rounded-up principal debts. `Underlying.totalUnderlyingForMint` adds `ceil(m*(free_i+netFees_i)/S)` outside principal. Thus it handles execution debt rounding more carefully than merely taking a rounded valuation times m/S. The basket amount resolver uses min-ratio capacity. Burn removes `floor(L_j*r/S)` from every range, applies manager fees to collected earnings, and pays pro-rata non-manager idle holdings plus principal in **both tokens**. No automatic scalar burn inverse was established.

**New positive lead:** `RouterSwapResolver.calculateSwapAmount` is direct arithmetic. It accepts an explicit 18-decimal price, gets current gross inventory ratio, subtracts an already-matchable basket and splits leftover value. For scalar token0 c, ignoring floors, with normalized `w=B0/B1` and token1-per-token0 price P:

`factor=wP/(1+wP); swapAmount=c*(1−factor)=c/(1+wP)`.

No binary search is present. But this is a fixed-price split estimate, not an exact fee/impact/post-swap-whole-book alignment solution. The helper uses `10^(18−decimals)` and does not establish compatibility with all local token metadata domains.

**Execution still class B:** router `_swapAndAddLiquidity` transfers the caller's `swapData.amountInSwap` to the executor; executor calls caller-supplied router/payload and checks a supplied output floor. After actual execution, the resolver computes a feasible basket; unused amounts return to the caller. This can tolerate imperfect splitting because consumption/refund semantics differ from the current exact-in full-credit law. Manager `rebalance` likewise receives explicit burn/mint arrays and swap payload.

Lesson: a deterministic split plus actual-fill accounting and explicit residual policy is a legitimate design, not necessarily optimal composition. An autonomous adapter could populate a fixed permitted route and arithmetic split, but full-consumption/alignment, same-manager blocked state and refund amendments remain our work.

## 6. Deep traces: Charm and Gamma — verify the admission layer

**Charm Alpha:** `https://raw.githubusercontent.com/charmfinance/alpha-vaults-contracts/main/contracts/{AlphaVault,AlphaStrategy}.sol`.

`deposit` pokes both positions, computes proportional amounts and pulls only used assets; it leaves deposits local. For positive reserves:

`cross=min(a0*B1,a1*B0); C0=ceil(cross/B1); C1=ceil(cross/B0); m=floor(floor(cross*S/B0)/B1)`.

A scalar input fails `cross>0` unless backing is one-sided. Withdraw pays pro-rata free inventory plus each position's proportional principal and fees. Fees are separately reserved for protocol, excluded from spendable shareholder balances; token0/token1 cannot be swept as accidental tokens.

**The strongest wing precedent:** AlphaStrategy `rebalance` calculates spacing-rounded base/bid/ask ranges, checks spot/TWAP deviation, and calls `vault.rebalance(0,0,...)`: zero swap. Vault removes base/limit, fills base, then a single-sided bid or ask with residual. Although the vault ABI permits strategy-supplied swap amounts, this specific strategy derives its ranges on-chain and supplies zero. Two aggregated positions, no user-created wing growth. That is reusable management architecture, **not scalar share admission**. Alpha Pro's separately fetched official docs add configurable full-range weight and timing controls; neither product is inherently full-range-only. Do not copy its cooldown/delegate rules over current public-repair law silently.

**Gamma:** `https://raw.githubusercontent.com/GammaStrategies/hypervisor/master/contracts/{Hypervisor,UniProxy,ClearingV2}.sol` plus [official developer portal](https://docs.gamma.xyz/gamma/lp-vaults/developer-portal).

Hypervisor v1.3 has direct spot-value mint:

`m=floor(S*(c1+floor(c0*P/10^36))/(B1+floor(B0*P/10^36)))`.

It updates/collects fees, transfers a configured fraction to feeRecipient, optionally adds to base and limit, and holds residuals. **Reading this alone would falsely suggest universal scalar admission.** It requires `msg.sender==whitelistedAddress`. UniProxy calls ClearingV2, whose `clearDeposit` normally requires both amounts positive and both ratio checks; only `freeDepositList[pos][from]` bypasses those constraints. Base-range and optional TWAP checks still apply. Withdrawal returns both tokens; rebalance is owner-directed, two ranges. Headings advertising “one-sided/lop-sided” are therefore insufficient evidence of public arbitrary unilateral entry. Do not copy a privileged spot-NAV bypass as a secure solution.

## 7. Deep trace: Bunni V2 — V4 buffering is not scalar admission

Primary prefix **BU**=`https://raw.githubusercontent.com/Bunniapp/bunni-v2/main/src/`: `BunniHub.sol`, `lib/BunniHubLogic.sol`, `periphery/BunniQuoter.sol`, `lib/RebalanceLogic.sol` read.

For an initialized two-legged book, `_depositLogic` sizes proportional amounts from requested maxima; `_mintShares` uses `min(floor(S*C0/B0),floor(S*C1/B1))`. A zero-backed leg is explicitly special-cased. Bootstrap uses the liquidity-density function and fixed initial share scale with locked minimum. This is not arbitrary scalar entry against two positive reserves.

Accounting splits raw PoolManager claims and ERC4626 reserves. Actual reserve-deposit `previewRedeem` value accommodates exit fees; unused underlying and ETH have refund rules. Withdraw removes proportional raw balances and proportional reserve shares valued in underlying, returning both currencies. am-AMM conditions can require queued withdrawals. Both ordinary deposit and withdrawal call `poolManager.unlock`; they are not nested-unlock-compatible sleeve routes.

Quoter mirrors the money-path calculations, but its live reserve-allocation calculation differs from the read HubLogic's target-ratio allocation. Do not infer perfect preview parity merely because a view exists. RebalanceLogic computes an oracle-price order `input≈idle*p/(p+r)`, then creates a Flood order for fillers—later management, not synchronous user conversion. Shape liquidity, idle liquidity, raw claims and external vault shares are distinct quantities.

The repository's own [README](https://raw.githubusercontent.com/Bunniapp/bunni-v2/main/README.md) warns that the relevant issues remain unfixed and not to use this code in production as-is. I rely on that primary warning only; no exploit amounts or mechanics are asserted here.

## 8. Other evidence and ranked shortlist

**Range** ([source](https://raw.githubusercontent.com/Range-Protocol/contracts/master/contracts/RangeProtocolVault.sol)) corroborates exact-share basket funding `C_i=ceil(m B_i/S)`, direct one-leg domains, one active range, manager-sized swap and proportional two-token burn. Manager fee/performance reserves are excluded; no missing scalar capability is supplied by `getMintAmounts`.

**ICHI:** [official SDK README](https://raw.githubusercontent.com/ichidao/ichi-vaults-sdk/main/README.md) says one deposit amount must be zero and `withdraw` returns both vault tokens; native withdrawal only unwraps the wrapped native leg. This is positive scalar-entry evidence, not proof of a scalar exit or exact NAV formula. Contract source could not be closed here.

**DeFiEdge:** indexed [official whitepaper](https://learn.defiedge.io/) explicitly describes either-token deposits held locally and later manager deployment, oracle share pricing and deviation reverts. The direct litepaper fetch failed; source/license/formula remain unverified. This is an important positive lead rather than justification to invent missing Solidity.

**Ranked reuse shortlist:**

1. **Aperture terminal analytic solver and autonomous direct-pool realization.** Highest-priority new mathematical evidence; strict no-discovery and incumbent book extension need proof.
2. **Beefy deficit admission/imbalance-charge concept plus two-range placement.** Concrete alternative economics, but incomplete directional coverage and scalar exits must be added; source/version mismatch on charges must be closed.
3. **Arrakis arithmetic split plus actual-fill/residual architecture.** Useful if the owner accepts capped consumption/refunds or another explicit residual policy; not exact whole-book composition as written.
4. **ICHI/DeFiEdge local unilateral valuation.** Closest product-level precedent for synchronous common-share admission without a deposit swap; promote only after complete code/licensing review.
5. **Charm bounded base+limit management.** Most directly reusable wing architecture; never offered as a basket-only final product.

## 9. Compatibility, economic limits and human checkpoint

Current local authority was re-read: PRD D1–31 `:28–58`; implementation plan `:119–150`; Orbital held-rate addendum `:828–835` and B6 `:35–42`; canonical Crane architecture/testing and local hook-package guidance. Local `HTransitionPlanner.sol:73–108` still discovers caller composition. Native SY `contracts/vaults/standard/sy/NativeStandardYieldTarget.sol:20–76` requires scalar SE routes. Here H denotes the full Hookless prefix under `contracts/vaults/standard/exchange/protocols/uniswap/v4/fullSpread/hookless/`.

**Reusable math is not interchangeable settlement.** V3 direct pool callbacks/NFT custody must become V4 PoolManager unlock/delta settlement, owner/ticks/salt positions, correct protocol/LP/hook fee accounting and native-currency handling. Context7 `/uniswap/v4-core` confirms nested unlock rejection and that `modifyLiquidity` callerDelta already includes fees. V4 hook custom accounting such as Bunni is not equivalent to a zero-hook managed CL position.

None of the source-traced products supplies our already-unlocked, same-manager scalar sleeve behavior. Keep entitlement priced against complete backing but pay only actual local cover; earned uncollected fees are not cash. Maintain `B=D+F+E` once, with fees/reserved obligations distinguished, and conserve actual token flows including settlement rounding loss. Maintain source-agnostic eligible pretransfer credit and complete post-workflow booking. External pull-only/refund designs do not automatically preserve that law.

Economic choices are real: fixed allocation accepts residuals/nonoptimal fills; oracle admission introduces feed/staleness and LP-marking risk; internal inventory absorption transfers exposure and needs a charge/risk domain; wings change future exposure without pricing fungible shares. Spot/TWAP gates and caps are not security proofs. Keep 1/50/25/10 bp meanings unless explicitly amended; neither a new oracle divergence bound nor a foreign strategy's fee is an approved substitute.

For autonomous composition, direct input-for-shares at a fixed, correctly projected rate could replace outer claim inversion. However, no inspected precedent supplies an exact inverse of our entire idle composed mint or two-leg scalar redemption. `OExitQuoteLib.sol:357–371` continues bisection after eight interpolation attempts; `_invertBufferForEffective` also remains distinct. `OMath.sol:332–360` searches the outer split. A cheaper inner helper does not remove those searches. Preserve shares-times-configured-rate reserve valuation and Pons separation.

**Next human decision:** authorize a bounded formula-verification study of Aperture's terminal solver and Arrakis's fixed-split/residual alternative, while closing ICHI/DeFiEdge source evidence in parallel only through separately authorized research. Decide whether monotone tick-segment discovery is acceptable under “no binary search,” or retain strict no-sizing-discovery and require a single-segment certificate. Do not choose basket-only. No implementation until the complete scalar route matrix, accounting policy and actual local-cover domains are approved.

Later gates: independent integer references, incumbent LP fees/repricing and multi-range overlays, post-removal swap state, meaningful minima/maxima, exact preview/transition/execution parity, dust and donation cycles, overflow/decimal domains, and end-to-end measurements on pinned states under unchanged caps. No measurement performed here.

## 10. Source/version/license and access ledger

External raw fetches lack line numbering; I cite exact files/functions rather than fabricate line numbers. Local references above are tool-provided path:line evidence. Every URL in this report was accessed or returned as primary-source search evidence on **2026-10-03**, with that distinction stated.

* **Aperture:** named commit above; OptimalSwap BUSL-1.1/pragma ≥0.8.8, Automan ^0.8.18. [Pinned LICENSE](https://raw.githubusercontent.com/Aperture-Finance/uniswap-v3-automan/c40aaa98cf49baf454fbb7a8ee6709862e27038e/LICENSE) specifies change date 2026-07-01 and GPL-2.0-or-later. That date has passed; confirm version applicability, dependency licenses and combined-work obligations before source reuse. Not simply “permissive.”
* **Beefy:** pinned audit snapshot, MIT headers, Solidity 0.8.23. Official later docs are not proof that that snapshot implements the later imbalance fee.
* **Charm Alpha:** moving main, Unlicense headers, 0.7.6; Alpha Pro license/source pin not established.
* **Arrakis:** moving main, core BUSL-1.1/0.8.13; inspected periphery UNLICENSED/0.8.13. GitHub content blob for core ArrakisV2: `710ff8d6970c13b83a6de83ed0b7cd30e2ee6ba4`—a file identity, not a commit/deployment pin. Source-copy permission remains a gate.
* **Gamma:** master; named versions above, BUSL-1.1/0.7.6. Hypervisor content blob `2dd8dc38083e3da6d85aff9160a61842df97bc41`. No current deployment or change-license conclusion.
* **Range:** master, MIT/0.8.4; exact deployed implementation unverified.
* **Bunni:** main; inspected files MIT/^0.8.19, repository warns other files are AGPL-3.0. Hub blob `5491527b653d2e85225cd4e3a2d61f985be6adf6`; no deployed pin or blanket license clearance.
* **Documentation-level URLs:** [Steer examples](https://github.com/SteerProtocol/steer-sdk-examples), [published SDK](https://registry.npmjs.org/%40steerprotocol%2Fsdk), [Mellow legacy](https://docs.mellow.finance/mellow-alm/overview/strategies/uni-v3-boosted-strategy), [Revert](https://docs.revert.finance/revert/technical-docs/revert-lend), [Arrakis Pro redirect](https://docs.arrakis.finance/text/arrakisModular/quickstart/quickstartPublic.html), [Alpha Pro](https://learn.charm.fi/charm/technical-references/core/alphaprovault). SDK license badges do not license the underlying vault contracts.

**Access gaps, not retried:** raw `ichidao/ichi-vaults/main/contracts/ICHIVault.sol` 404; Etherscan `0x683f081dbc729dbd34abac708fa0b390d49f1c39#code` 403; guessed Gamma `Clearing.sol` and Arrakis `ArrakisV2RouterSwapExecutor.sol` 404 (actual differently named files discovered through public directory listings); guessed Beefy `cowcentrated-contracts/main/.../BeefyVaultConcLiq.sol` 404 (audit snapshot separately discovered); DeFiEdge litepaper transport failure. No guard or SDK unavailability occurred. No local ordinary-file failure; previously missing wrong local paths were not retried.

**Confidence:** high in directly read function classification and existence of the analytic/deficit/wing mechanisms; medium in transferability; unresolved in complete autonomous scalar compatibility, economic safety and performance. Stop for the human; no execution authorized.
