# S01 PRD: USDG lending to the NET Loopback Morpho market

- Created: 2026-09-06
- Last updated: 2026-09-06
- Status: Strategy draft with required USDG liquidity sleeve; sleeve parameters and deployment validation remain open.
- Strategy: S01 in the [NET/Morpho/Pendle research catalog](NET_MORPHO_PENDLE_STRATEGY_RESEARCH.md).
- Implementation basis: extend the existing `MorphoBlueStandardExchange` with a managed USDG liquidity sleeve.

## 1. Problem and intended behavior

Establish the simplest concrete earning position from the research catalog: retain a managed USDG liquidity sleeve in the SE, supply the remaining allocation to the existing wsNET-collateralized Morpho Blue market, and retain accrued lending interest in the position. The sleeve provides immediately available USDG for withdrawals when the underlying market lacks free liquidity, up to the cash actually held.

The accumulation target is total USDG asset value per strategy share, including both the sleeve and accrued lending assets. Entry, accounting, earnings, and exit all use USDG. This gives subsequent strategy PRDs a concrete baseline for distinguishing embedded earnings, separately claimable income, and capital realization.

Interest remains in Morpho's supply accounting without a harvest-and-redeposit transaction. The rate varies with market conditions; neither a minimum yield nor principal preservation is guaranteed. Borrower bad debt can reduce the supplied position's value. [Morpho market mechanics](https://docs.morpho.org/learn/concepts/blue/), [interest model](https://docs.morpho.org/learn/concepts/irm/)

The sleeve is a required addition, requested on 2026-09-06. It provides finite withdrawal capacity; it does not guarantee full redemption during an unlimited withdrawal run or protect the lent allocation against bad debt. USDG retained as cash earns no Morpho interest, so sizing must evaluate the withdrawal coverage and yield tradeoff.

## 2. Why this is the first candidate

| Candidate | Additional design work compared with S01 |
|---|---|
| S01: USDG lending with sleeve | Existing SE implementation, component PRD, unit/fork scaffolding, and DETF composition bases; requires new reserve allocation and replenishment behavior |
| S02: wsNET holding | Simple exposure, but requires settling wrapper valuation and the intended entry/exit surface |
| S05: PT holding | Adds token pricing, dated redemption, and maturity policy |
| S04: YT holding/compounding | Adds accrued-claim ownership, expiring entitlement valuation, claim execution, and renewal |
| S06: Pendle LP | Adds component valuation, liquidity operations, and separate reward accounting |
| S09 / C15: collateral and borrowing | Adds debt accounting, health constraints, repayment funding, and unwind policy |

This is an engineering-scope assessment, not a ranking of investment safety or expected returns. S01 validates native interest accumulation; later compositions must still specify how income is realized and traded into a different position.

## 3. Relationship to existing product law

The canonical component specification is [MorphoBlueStandardExchange_PRD.md](../../contracts/vaults/standard/exchange/protocols/morpho/blue/MorphoBlueStandardExchange_PRD.md), with its [implementation and testing plan](../../contracts/vaults/standard/exchange/protocols/morpho/blue/MorphoBlueStandardExchange_IMPLEMENTATION_AND_TEST_PLAN.md).

This document specializes that component to the NET Loopback market and requires a liquidity-sleeve extension. The current component PRD and implementation describe no managed sleeve and full supply of measured deposits. Those statements describe the existing implementation, not the requested S01 behavior.

Before implementation, carry the sleeve requirements into the canonical component PRD and implementation/test plan, including the no-sleeve/full-supply decisions D25–D26, idle-asset descriptions, and replenishment/quote behavior. The user's sleeve requirement authorizes this design change; no additional approval of the requirement is needed. This draft does not otherwise change existing fees, supported token routes, deployment rules, or token policy. A discovered discrepancy between product law and implementation must be recorded and resolved in the canonical package documents.

The first milestone is the underlying S01 position. Its first consuming DETF is now specified in the [NET leverage-demand USDG stable DETF PRD](../../contracts/vaults/detf/protocols/dexes/uniswap/v4/detf/NET_MORPHO_USDG_BALANCER_STABLE_DETF_PRD.md): the existing unified `UniswapV4Detf`, a two-currency Balancer-style stable Uniswap V4 hook, Policy mode, and a target of 1 USDG per DETF. The current Balancer hook requires four currencies and has integration/operation gaps, so that host capability and the S01 sleeve must be completed before deployment. Bootstrap, numeric calibration, and lifecycle validation remain open. An SE receipt by itself is not a DETF; S01 can also be reused in later compositions.

## 4. Market binding and token roles

Bind one existing market on Robinhood Chain mainnet, chain ID `4663`:

| Field | Intended value |
|---|---|
| Morpho Blue | `0x9D53d5E3bd5E8d4Cbfa6DB1ca238AEA02E651010` |
| Market ID | `0xaa586d26a6fe62d9c0f0948fede6e2130500ac7a655587447e2d4a37e6330589` |
| `loanToken` / SE `rateAsset` / `asset()` | USDG: `0x5fc5360D0400a0Fd4f2af552ADD042D716F1d168` |
| Market `collateralToken` | wsNET: `0x63C12667638f2Ae6fC6ae09B43D98Ec84a8586eA` |
| Oracle | `0xCDE9599059f8Ae6D6B9F33A0aF7877827ec75F16` |
| IRM | `0x2BD3d5965B26B51814AC95127B2b80dD6CcC0fa1` |
| LLTV | `0.625e18` |
| SE share | The deployed `MorphoBlueStandardExchange` vault address |

These intended identifiers come from the [research record](NET_MORPHO_PENDLE_STRATEGY_RESEARCH.md) and [Robinhood constants](../../lib/crane/contracts/constants/networks/ROBINHOOD_MAIN.sol). Acceptance requires reading `idToMarketParams`, verifying the resulting ID and market existence, and recording block context. The market collateral identifies the loan exposure; the lending strategy does not receive or manage wsNET collateral.

## 5. Separate token-flow requirements

### Position increase

- Input token: USDG.
- Output: newly issued SE shares backed by the resulting USDG position, under canonical fee and rounding rules.
- Allocate measured inbound USDG between the directly held sleeve and Morpho according to the sleeve policy in section 6.1. Deposits replenish a sleeve shortfall before additional capital is supplied; full supply of every deposit is no longer the required behavior.
- Any attempted supply must preserve atomic deposit accounting: a failed supply reverts that deposit transaction. Do not silently introduce an alternative deposit-success mode when a required supply fails.
- The SE owns its Morpho position; users own SE shares.

### Yield production

- Separately claimable yield-token list: empty for this first scope.
- Embedded earnings asset: USDG, through accrued Morpho supply value.
- Retain accrued interest in the supplied position. Interest accrual itself needs no periodic claim or reinvestment swap; replenishing the separate cash sleeve may require a maintenance transaction.
- Unexpected ERC-20 balances and external incentive campaigns are not included as supported yield or counted in this strategy's value.

### Position reduction

- Input: SE shares, or an exact USDG withdrawal request through the supported interface.
- Output token: USDG.
- Pay available sleeve USDG first, then obtain any remaining amount from Morpho if market liquidity permits. An otherwise valid withdrawal covered by the sleeve must not depend on a Morpho withdrawal or on successful sleeve replenishment.
- Withdrawal realizes part or all of the accrued position and consumes the corresponding shares.
- Realizing an amount described economically as interest still follows the withdrawal path; there is no separate Morpho coupon claim.

## 6. Functional and accounting requirements

| ID | Requirement | Required evidence |
|---|---|---|
| R01 | Bind exactly the intended existing market, with no replacement by another market during validation | Recorded onchain parameters, computed ID, market existence, and explicit binding assertion |
| R02 | Expose the canonical USDG/SE exact-in and exact-out routes and corresponding ERC-4626 money paths | Existing route coverage plus deployment-specific execution evidence |
| R03 | Apply the component's measured-inbound, fee, rounding, allowance, and deadline rules | Canonical production-proxy tests and actual USDG decimal verification |
| R04 | Value the SE as idle USDG plus its expected accrued Morpho supply assets | Compare views and post-operation state with Morpho accounting |
| R05 | Retain lending interest in position value without an artificial harvest action | Interest-bearing fixture with unchanged user share balance and correctly changing assets per share |
| R06 | Distinguish accrued value from immediately withdrawable value | Low-liquidity behavior, conservative withdrawal limits, and atomic failure when cash is insufficient |
| R07 | Reflect realized lending losses through current Morpho share value | Controlled bad-debt scenario using production protocol components; no unconditional monotonic-share-price assertion |
| R08 | Keep S01 supply-only | Its Morpho position has no borrow shares or posted collateral; ordinary operations preserve this property |
| R09 | Preserve existing registry/package deployment and opaque SE composition | Component deployment checks; later DETF lifecycle checks against the selected existing family |
| R10 | Identify fees actually applicable to the configured instance | Fee-oracle configuration and Morpho fee state, with fee treatment reconciled to the canonical component PRD |
| R11 | Maintain correct asset attribution across users | Existing donation, pretransfer, rounding, and deposit/withdrawal adversarial requirements |
| R12 | Report observations without promising a fixed return or instant redemption | Rate/liquidity outputs tied to observed state and clear distinction between value and executable withdrawal |
| R13 | Hold a managed, non-zero target USDG sleeve directly in the SE | Defined sizing policy and deposit allocation; actual cash is distinguishable from lent assets and accidental dust |
| R14 | Replenish the sleeve using inflows and bounded withdrawals from Morpho when liquidity permits | Defined trigger/execution policy; shortfall persists honestly when the market cannot fund replenishment |
| R15 | Permit withdrawals to consume the sleeve during market illiquidity | Sleeve-covered withdrawal succeeds with zero free Morpho cash; exhaustion beyond total available cash reverts atomically |
| R16 | Preserve full-value previews while modeling sleeve operations accurately | Ordinary previews remain independent of liquidity caps; transition quotes reflect revised deposit/withdrawal allocation and executable liquidity |

Conceptual accounting:

```text
SE totalAssets = idle USDG + expected accrued USDG supply assets owned by the SE

available USDG = idle USDG
               + min(SE's expected supply assets, available market cash)
```

Share conversions, fees, and rounding use the canonical implementation rather than a new parallel calculation. A higher balance due to a new deposit is not investment income. Gains/losses must be evaluated per share and with external flows and fees accounted for.

### 6.1 Required liquidity-sleeve behavior

**Custody and sizing.** The sleeve consists of unencumbered USDG held directly at the SE address. Morpho supply shares or deposits in another lending protocol do not count as sleeve cash. Specify a non-zero target and how it is derived from current asset value. A percentage of total USDG NAV is the initial model to evaluate; the percentage, any lower/upper bands, rounding, and parameter configuration policy remain open. Do not select an arbitrary reserve percentage in implementation.

**Deposit allocation.** Calculate the sleeve requirement consistently with the resulting post-deposit position and existing share/fee accounting. Use inflows to fill a reserve shortfall and supply only the allocation above the required retained cash. Measured inbound assets must be counted once. Donations are assets of existing shareholders under existing policy; they must not be credited again as the next user's deposit.

**Withdrawals.** The sleeve target is a replenishment objective, not a minimum cash balance that blocks an otherwise funded exit. Withdrawals may take sleeve cash below target or exhaust it. Use cash first and source only the unmet payment from Morpho. A maintenance attempt to restore the target must not revert an otherwise funded withdrawal. When cash plus available Morpho liquidity is insufficient, preserve the existing atomic insufficient-liquidity failure behavior; this requirement does not add an asynchronous withdrawal queue.

**Replenishment and excess cash.** Define when to withdraw available USDG from Morpho to restore the target and when to supply excess cash. Replenishment must be bounded by the shortfall, owned lending assets, and available market liquidity. It cannot manufacture cash during a market-wide liquidity shortage. Settle the maintenance entry point, permissionless execution conditions, transaction bounds, and any minimum useful rebalance amount during design. Maintenance must operate only on this SE and its bound market, without caller-selected recipients or arbitrary routes. Borrowing to fund the sleeve is outside this supply-only strategy.

**Accounting and quotes.** Sleeve cash and accrued lending assets together form full NAV. Moving USDG between the two is not yield, a new deposit, or a share-minting event. Ordinary `previewExchangeIn`/`previewExchangeOut` continue to price the requested amount using full NAV, without gating on `maxWithdraw` or `maxRedeem`. Those limits separately reflect the owner's position and currently available sleeve plus Morpho cash. The separate transition-quote simulation must reproduce the revised allocation and withdrawal behavior, including liquidity checks, without double counting cash.

**Crisis behavior.** Record actual cash, target cash, the shortfall/excess, and immediately withdrawable assets in the eventual observation interface. Validate depletion by successive withdrawals, zero free Morpho cash, later replenishment from new deposits or restored market liquidity, interest-driven changes in the target, and realized losses in the lending allocation. Reserve sizing must also consider redemption access during losses: early withdrawals from cash can leave later holders with more exposure to the remaining illiquid loans. The sleeve does not resolve that allocation risk by itself.

## 7. Research and validation register

Evidence status distinguishes source inspection from execution. No tests were run for this draft.

| ID | Question to confirm | Current evidence | Remaining work |
|---|---|---|---|
| V01 | Does the intended deployment match the recorded market? | Application research and repository constants | Read every parameter at a recorded block; confirm exact market ID and deployed code |
| V02 | Does actual USDG match the supported token assumptions? | USDG is the recorded loan asset; existing token policy permits non-18 decimals | Read decimals and verify transfer/approval behavior on the target deployment; do not add a token allowlist |
| V03 | Does the existing SE correctly supply and redeem this exact market? | Implementation exists; generic Robinhood fork tests exist | Add or specialize evidence for Loopback specifically, including sufficient-liquidity exits |
| V04 | Is accrued accounting correct between SE transactions? | Existing live-NAV implementation and interest test suite | Execute relevant tests and reconcile with Morpho state for the intended configuration |
| V05 | What happens during liquidity exhaustion and borrower loss? | Morpho semantics and existing liquidity/adversarial scaffolding | Validate the distinct effects of illiquidity and realized bad debt on value and exits |
| V06 | Do Net oracle guards affect lending operations directly or only the market's recovery behavior? | Core supply/withdraw paths do not require a collateral price; liquidations do | Validate against deployed dependencies and document the consequence for lender liquidity/loss exposure |
| V07 | Which current fees affect returns and share issuance? | Canonical package policy and source | Record actual configured fees and check implementation/specification agreement |
| V08 | Which DETF host/family configuration should consume this SE? | The [first DETF composition PRD](../../contracts/vaults/detf/protocols/dexes/uniswap/v4/detf/NET_MORPHO_USDG_BALANCER_STABLE_DETF_PRD.md) selects unified `UniswapV4Detf`, a two-currency Balancer-style stable host, Policy mode, and a 1 USDG target | Complete the host's two-currency capability and unified ABI/liquidity operations, calibrate deployment parameters, and validate the complete lifecycle with the exact S01 binding |
| V09 | What sleeve size and target/band model meet the desired withdrawal coverage? | User requires a directly held USDG sleeve; no numeric parameters selected | Model withdrawal sizes/sequences, zero market cash, NAV changes, and the lending-yield reduction; define parameter bounds and configuration policy |
| V10 | How is the sleeve replenished without compromising funded withdrawals? | Existing idle-first payout behavior is reusable; managed allocation/replenishment is absent | Specify post-deposit allocation and maintenance execution, bounds, atomicity, and depleted-sleeve recovery |
| V11 | Do all entry points and quotes agree after the sleeve extension? | Current ordinary previews use full NAV; transition quotes currently model full deposit supply | Validate exact-in/out and ERC-4626 paths, fee/pretransfer accounting, maintenance, crisis exits, and corresponding transition states |

### Concrete coverage gap found during drafting

The current [Robinhood fork suite](../../test/foundry/fork/robinhood_main/vaults/standard/exchange/protocols/morpho/blue/MorphoBlueStandardExchange_RobinhoodFork.t.sol) selects among USDG markets backed by SGOV, CRCL, ORCL, and NBIS. Its candidate list does not contain the NET Loopback market. The shared [fork base](../../contracts/vaults/standard/exchange/protocols/morpho/blue/test/bases/TestBase_MorphoBlueStandardExchangeFork.sol) chooses a candidate with free cash.

Those tests provide reusable scaffolding, but their existence or success cannot establish S01's exact-market validity. S01 evidence must bind the intended ID explicitly and must not silently fall back to an unrelated market when liquidity is unavailable. Use a reproducible block where supported and record the block/hash and relevant state; a provider's lack of archive support is a tooling constraint to resolve, not evidence that another market is equivalent.

The existing [CP Morpho Blue DETF base](../../contracts/vaults/detf/protocols/dexes/uniswap/v4/detf/TestBase_UniswapV4Detf_Cp_MorphoBlueSe.sol) creates a hermetic market. It demonstrates a composition path to examine, not certification of the live NET configuration.

## 8. Acceptance for the first strategy milestone

S01 is validated for the intended deployment only after:

1. V01–V07 and V09–V11 have evidence or a documented finding that changes the draft requirements; source-only assumptions are not presented as executed proof. Sleeve sizing and maintenance behavior are specified before implementation is treated as complete.
2. Required existing component tests pass, and identified target-specific gaps have meaningful coverage.
3. Deposits, accrued value, sleeve allocation/replenishment/depletion, withdrawals, insufficient liquidity, fees, realized losses, and quotes match R01–R16 where applicable to the SE milestone.
4. The evidence names the exact market and block/state context, along with material execution limitations.
5. Any discovered implementation/specification discrepancy is resolved in the canonical component package.

The later DETF milestone additionally completes V08 and the consuming DETF PRD's bootstrap, mint/burn, bond/claim, reserve-host, peg-performance, and stress acceptance requirements. S01's USDG asset value must not be presented as the DETF share price or as a complete DETF reserve model.

When implementation work begins, use the repository's existing production-first testing and registry workflows. Reuse relevant tests and TestBases. Production contract edits require `forge build` before `forge test`; fork testing uses `FOUNDRY_PROFILE=fork`. The documentation-only drafting step does not run those suites.

## 9. Lessons to carry into the next strategy PRD

- A position can compound through native accounting without separately producing claimable tokens.
- Describing a withdrawal as spending interest requires a capital/earnings attribution policy in the consuming strategy; the underlying withdrawal itself does not make that distinction.
- Value, liquidity, and investment safety are separate properties.
- Full-NAV previews do not guarantee cash availability. A managed sleeve adds finite immediately withdrawable cash and requires its own sizing, allocation, and replenishment policy.
- Existing protocol support reduces implementation work, but evidence for a neighboring market does not validate the target market.
- S01 supplies a reusable USDG earning position for later C01/C02 compositions. Those require additional trade routes and an explicit reinvestment budget.

Potential next documents are S02 for staked-NET accumulation and then a selected claim/reinvestment strategy. Their order remains open; this draft does not select a broader implementation program.

## 10. Change log

| Date | Change |
|---|---|
| 2026-09-06 | Initial S01 draft: existing component reuse, exact market binding, distinct token flows, requirements/evidence matrix, native compounding, valuation/liquidity separation, and the current Robinhood fork coverage gap. |
| 2026-09-06 | Added the user-required USDG liquidity sleeve. Revised deposit allocation and withdrawal behavior; added R13–R16, sleeve design requirements, V09–V11, and acceptance coverage. Preserved full-NAV exchange previews and recorded the required canonical component PRD/plan revision. Numeric sizing and maintenance parameters remain open; contracts were not changed. |
| 2026-09-06 | Linked the first consuming DETF PRD and updated V08: unified DETF with a two-currency Balancer-style stable host and a 1 USDG target. Recorded remaining host capability, calibration, lifecycle, and stress-validation work; S01 remains reusable in other DETFs. |
