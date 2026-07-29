# pons v2 — components and economics

Source: https://docs.ponsfamily.com/v2 · fetched 2026-07-29

## Status (critical)

- **Mainnet addresses are not published.**
- Three audits in progress (SB Security, Dingbats, Pashov Audit Group).
- Treat v2 as **unaudited and undeployed** until reports + addresses appear on the docs site.
- Contact: contact@ponsfamily.com for testnet / early access.

## Component map

| Contract | Cardinality | Responsibility |
|----------|-------------|----------------|
| Launch factory | Singleton | Launch, configs, graduation orchestration, CTO proposals |
| Bonding curve | Per launch | Pre-graduation buy/sell; holds sellable supply |
| Launch token | Per launch | Fixed-supply ERC-20; all supply to curve at create |
| Meme hook | Singleton | Uniswap V4 hook; post-grad fees |
| Fee escrow | Singleton | Pull-based creator/protocol balances (ETH + ERC-20) |
| Buyback vault | Singleton | Locked buybacks; 5-year weighted linear vest |
| Launch locker | Singleton | Permanent LP position + excess supply at graduation |

## Launch configs

Append-only list on factory (`launchConfigCount` / `getLaunchConfig(id)`). Fields include:

- `supply`, `curveFeeBps`, `phantomQuote`, `graduationThreshold`
- `poolFee`, `tickSpacing`, `enabled`

Disabled configs stay readable for history but revert with `LaunchConfigDisabled` on create. Prefer re-reading enabled configs at create time.

Pin terms with `previewLaunchEconomics(launchConfigId, pairToken)` → pass as `expectedEconomics` on `launchToken` or get `LaunchEconomicsMismatch`.

## Quote assets

- Native ETH: pass **zero address** as `pairToken`.
- ERC-20: must pass `approvedPairTokens` and non-zero `pairTokenEconomics` (phantom + threshold + decimals).
- Unapproved → `PairTokenNotApproved`.
- Amounts use **asset decimals** (do not assume 18).
- Approval is not endorsement; owner can stop new launches against an asset without affecting live ones.

## Reserved pool supply

```text
reserved = supply × phantomQuote / (phantomQuote + threshold)
```

Same settings → same pool size and graduation price regardless of buy path (one whale vs many small buys).

## Pricing reserves (curve)

| View | Meaning |
|------|---------|
| `quoteReserve()` | Pricing reserve **including** phantom quote |
| `realQuoteReserve()` | Actually collected quote still held (net fees) |
| `tokenReserve()` | Tokens still on curve (incl. reserved floor) |
| `sellableTokens()` | Still buyable before close |
| `reservedTokens()` | Fixed holdback for pool |
| `readyToGraduate()` | `sellableTokens() == 0` |

Marginal price ≈ `quoteReserve / tokenReserve` (phantom included).

## Graduation phases

| `phase` | Name | Route trades to |
|---------|------|-----------------|
| 0 | NotGraduated | Curve |
| 1 | Swept | No trading; finish with `createGraduatedPool(token)` |
| 2 | PoolCreated | Uniswap V4 pool |
| 3 | Rescued | Recovery path; surface explicitly |

Auto-graduation runs inside the finishing buy; on gas failure: `AutoGraduationFailed` → anyone may call `createGraduatedPool` (permissionless, retryable).

Safety valve: if stuck mid-graduation **7 days**, protocol recovery may return collected funds; launch permanently marked rescued.

## Uniswap V4 pool key (post-grad)

- Currencies: launch token + quote sorted by address (native ETH = zero → always currency0).
- `fee`: from launch record — **zero** on core pool; hook charges protocol fee.
- `tickSpacing`, `hooks`: from launch record + shared meme hook.
- Liquidity: single full-range position transferred to locker — **no withdraw**.

Hook: validates factory registration on init; after swap accrues fees/tax; does not gate traders, tax transfers, or hold user funds beyond pending fee sweep balances.

## Creator controls after launch

Only:

1. Redirect fee recipient (`transferCreatorFeeRecipient`) — future earnings + buyback share.
2. Toggle buybacks off/on (creator can enable; protocol can disable only).

Cannot: mint, freeze, blacklist, raise tax, change quote, unlock LP.

## Buyback vest

- Funded from **creator's** fee share (optional).
- Bought tokens locked; released over **five years**; weighted `vestingStart` moves with new buybacks.
- `release(token)` is permissionless once vested; splits to creator + protocol via escrow.
- Failed sensible buyback → money goes to creator as normal (no jam).
