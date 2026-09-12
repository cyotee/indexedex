# Fee-accrual DETF: Pendle before Morpho

- Created: 2026-09-08
- Last updated: 2026-09-08
- Status: Candidate recorded for later consideration, not an accepted implementation design.
- Related research: [NET, Morpho, and Pendle strategy catalog](NET_MORPHO_PENDLE_STRATEGY_RESEARCH.md).

This note preserves the proposed principal/yield separation discussed with the user. Recording the idea does not select allocations, authorize implementation, or establish that the required markets exist. Source observations below were made on 2026-09-08; no live deployment validation, transactions, or numerical strategy tests were performed.

## 1. User-established context

- The fee-accrual DETF will use common components and the existing unified Uniswap V4 hook-based DETF lifecycle, not a special type of DETF.
- A package should allow anyone to deploy the composition with different compatible tokens, SE vaults, markets, and rate providers.
- Regular ETH donations will come from liquidated fees collected from other DETFs, through the standard donation process. No amount or frequency has been specified.
- The project objective is to acquire and retain DTF exposure and obtain ETH to build liquidity in the Pons-launched DTF/ETH Uniswap V4 base pool.
- The user's complete strategy may span several DETFs. Research should validate predicted valuation, swap, inventory, debt, and liquidity effects; users choose whether the resulting management strategy is desirable.
- Continuous swap or withdrawal availability is not a universal strategy-selection requirement. Unavailable routes and deliberately scarce lending liquidity are states to model, while actual state transitions still require executable transactions.

In this note, **DTF** is the Pons-launched base token. **DETF** is the fee-accrual DETF's own share token, and **sDETF** is that DETF's funded staking receipt. ETH means WETH where an ERC-20 loan or input asset is required. The base DTF/ETH pool and the DETF's own reserve hook are distinct pools.

## 2. Candidate loop

The central idea is to put Pendle before Morpho: borrow against the principal claim while retaining funded rebase income separately.

```text
Fees liquidated from other DETFs
    -> ETH converted to an accepted donation input where required
    -> standard donation route
    -> additional protocol-owned reserve liquidity

Separately acquired fee-accrual DETF
    -> stake into sDETF
    -> deposit into staking SY
    -> split into PT + YT

PT
    -> collateral in a suitable Morpho market
    -> borrow WETH
    -> acquire DTF and add strategy-owned DTF/ETH base liquidity

Retained YT
    -> claim earned SY
    -> retain staking exposure, renew YT, repay borrowing,
       or fund further base liquidity
```

The donation and staking-acquisition branches are separate uses of capital. Donation does not issue the donor DETF or sDETF. Someone must supply or acquire the DETF used to create the Pendle position; the same ETH cannot fund both branches simultaneously.

## 3. Principal and rebase income

The existing staking SY uses static nine-decimal shares backed by funded sDETF exposure. Its accounting asset is DETF, not ETH. Its exchange rate reflects the funded staking index. See [DETFSYTarget](../../contracts/vaults/detf/common/sy/DETFSYTarget.sol), particularly `exchangeRate`, `yieldToken`, and `assetInfo`.

| Position | Economic exposure |
|---|---|
| PT | Dated principal claim denominated in DETF |
| YT | Funded staking-index growth through the series' expiry |
| SY | Combined staking exposure before separation |

This separates DETF-unit principal from additional DETF earned through rebases. It does not separate every source of investment return from principal. PT still bears changes in DETF's ETH value. Donation-driven backing or market-value changes are not automatically YT income.

The standard donation path acquires protocol-owned reserve LP without directly issuing staking rewards. Donations can affect subsequent expansion through reserve-backed synthetic pricing, subject to the existing expansion conditions and timing. They are not directly booked as funded staking yield. Sources: [UniswapV4DetfTarget](../../contracts/vaults/detf/protocols/dexes/uniswap/v4/detf/UniswapV4DetfTarget.sol), [DETFFundedBondTarget](../../contracts/vaults/detf/common/bondNft/DETFFundedBondTarget.sol), and [DETF alignment law](../../contracts/vaults/detf/DETF_ALIGNMENT_PRD.md), D34-D40 and D49-D50.

## 4. Why place Pendle before Morpho?

1. Principal can support ETH financing independently of the retained income allocation.
2. YT receipts can fund renewal, repayment, collateral acquisition, or LP additions rather than remaining embedded in the collateral token.
3. Seizure of PT does not automatically transfer separately held YT or the strategy's account-specific accrued YT claims to the liquidator.
4. Morpho's collateral valuation and lending terms price principal financing, while Pendle prices the remaining rebase entitlement.

Retained YT rebases do not automatically increase the quantity of posted PT principal. To strengthen the debt position with that income, the strategy must repay debt or acquire and post additional accepted collateral.

An ETH-denominated loan against DETF-denominated PT still has price exposure. No fixed ETH redemption value, market, oracle, LLTV, or borrowing level is selected by this proposal.

## 5. Alternative configurations

| Configuration | PT treatment | YT treatment | Financing source |
|---|---|---|---|
| Retain rebase income | Collateralize | Retain and compound claims | Morpho borrowing |
| Sell future rebases | Retain or collateralize | Sell | YT-sale proceeds, optionally plus borrowing |
| Advance principal value | Sell | Retain | PT-sale proceeds, surrendering principal ownership |

PT collateral plus retained YT was the assistant's suggested first modeling case, not a user-approved selection. Selling some YT is an alternative that brings forward capital from buyers of future funded rebases.

Earned YT claims survive expiry, but future earning rights do not. Claiming existing income and replacing an expired series are separate operations. Renewal availability, PT collateral maturity handling, and the no-successor fallback remain open.

## 6. Connection to DTF accumulation

The Pendle position initially commits fee-accrual DETF, not base-token DTF. Borrowed ETH connects that position to the base-token objective:

```text
Borrowed ETH
    -> buy DTF -> retain inventory or post separate DTF collateral
    -> buy DTF and retain matching ETH -> add base-pool liquidity
```

Track DTF held outside AMMs separately from DTF contained in owned LP. Collateral is restricted by the lending position; pool-held DTF remains tradable. The same DTF cannot be both posted collateral and base-pool inventory.

Two independent allocation decisions remain open:

- Borrowed ETH: retained DTF versus base liquidity.
- YT receipts: renewal versus collateral versus repayment versus base liquidity.

Only legitimately owned liquidity can be removed. Pons's locked launch position is not the strategy's withdrawable LP. The local [Pons V2/V4 SE fixture](../../contracts/test/bases/TestBase_UniswapV4StandardExchange_PonsV2.sol) illustrates adding separately funded liquidity to a graduated pool; it is not live-deployment evidence. The identified ETH donations, rather than an assumed base-pool LP fee stream, provide the external fee input for this candidate.

## 7. Position ownership and consolidation

**External ownership:** a user or another DETF acquires this fee-accrual DETF, splits its staking exposure, borrows against PT, and retains resulting LP or donates capital back. This can form one part of a multi-DETF strategy.

**Internal ownership:** an SE inside this fee-accrual DETF owns the PT/YT position. This is self-referential: the issuer's portfolio holds claims on its own staking product. Those claims are not additional independent external backing. Consolidated accounting, collateral valuation, and possible recursive provider calls need explicit analysis.

Neither ownership arrangement is selected. In both cases, the staking contract's held DETF remains reserved for sDETF backing. The strategy uses legitimately owned receipts, not that backing as a second spendable balance.

Borrowing can use externally supplied WETH or liquidity supplied by another component of the same portfolio. Self-lending still creates separate supply and debt records in a pooled market, not new net capital or reserved repayment cash. Regular donations are an external input to this DETF; at a broader multi-DETF boundary, distinguish redistribution of existing portfolio value from new external earnings.

## 8. Reusable component candidates

| Component | Responsibility |
|---|---|
| Existing unified V4 DETF and staking SY | Preserve ordinary lifecycle, donation, funded staking, and wrapper behavior |
| Pendle position SE | Mint PT/YT, retain and claim YT, and route PT to authorized collateral custody |
| Morpho borrowing SE or composed position SE | Manage the exact PT collateral series, WETH debt, repayment, and debt-aware position accounting |
| Existing V4 position SE | Own additional DTF/ETH base liquidity |
| Cross-position rate providers | Observe donations, funded rebases, maturity, debt, and lending utilization to influence trading terms |
| Reusable execution paths | Move actual claimed income and borrowed assets between positions |

This is a capability list, not a decision to create one package per row. The existing Morpho lending SE is supply-only; collateral and borrowing are not enabled by changing its configuration. Crane has reusable Morpho operations in [MorphoBlueService](../../lib/crane/contracts/protocols/lending/morpho/blue/services/MorphoBlueService.sol).

## 9. Questions for later consideration

1. Who initially owns and funds the DETF deposited into staking SY?
2. Is the PT/YT position external to this DETF or held through one of its SE allocations?
3. Which exact PT series, WETH lending market, oracle, and maturity policy support the borrowing position?
4. How do donations affect synthetic pricing, actual funded rebases, and PT/YT valuation over time?
5. What proportions of borrowed ETH and claimed SY feed each destination, and what changes those proportions?
6. How are PT replacement, earned post-expiry claims, and periods with no successor market handled?
7. Which concrete hook and provider equations produce the intended swap flows? Validate per family rather than assume rates have uniform effects.
8. What are the consolidated DTF/DETF holdings, owned base liquidity, supply claims, debt, and external capital flows across participating DETFs?

The proposed benefit to evaluate is control over the funded rebase stream: principal finances ETH deployment while retained YT serves a separate management policy. No return estimate, allocation, liquidity guarantee, or preferred leverage level has been established.

## 10. Change log

| Date | Change |
|---|---|
| 2026-09-08 | Recorded the Pendle-before-Morpho candidate at the user's request for later consideration. Preserved regular fee-funded ETH donations as user context, principal/rebase separation, PT collateral with retained YT, alternative configurations, DTF/base-liquidity routing, ownership choices, component candidates, and open questions. Documentation only. |
