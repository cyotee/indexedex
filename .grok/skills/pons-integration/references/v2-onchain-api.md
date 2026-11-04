# pons v2 — onchain API surface

Source: https://docs.ponsfamily.com/v2 · fetched 2026-07-29

**Addresses not published.** Resolve factory from docs when live; resolve per-launch `curve` and `token` from factory, never hardcode placeholders.

## Launch

### Enumerate configs

```ts
// launchConfigCount() / getLaunchConfig(id)
// LaunchConfig: supply, curveFeeBps, phantomQuote, graduationThreshold,
//   poolFee, tickSpacing, enabled
// Filter to enabled for create UX; keep disabled for historical explainability
```

### Pin economics and launch

```ts
// previewLaunchEconomics(launchConfigId, pairToken) → bytes32 expectedEconomics
// launchFee() → uint256
// launchToken(TokenParams, launchConfigId, pairToken) payable → (token, curve)
//
// TokenParams: name, symbol, logo, description, socials,
//   creatorFeeRecipient, creatorTaxBps, buybackEnabled, expectedEconomics
// pairToken = address(0) for native ETH
```

Pre-checks:

- `launchEnabled()`, `whitelistedLaunchers(addr)` if restricted
- `approvedPairTokens(pair)` + `pairTokenEconomics` (phantom, threshold, decimals)
- `creatorTaxBps` ≤ `maxCreatorTaxBps()`

## Curve trading

```ts
// buy(quoteIn, minTokensOut, recipient) payable → tokensOut
// sell(tokensIn, minQuoteOut, recipient) → quoteOut
// isNativeQuote() / pairToken()
```

| Quote type | Rules |
|------------|--------|
| Native | `value == quoteIn`; refunds same tx |
| ERC-20 | Approve curve for `quoteIn`; **no** native value |

Partial final buys: read `tokensOut` from return/`CurveBuy`; may also see `CurveBuyRefunded`. After grad: `CurveGraduated` — route to V4.

Permissionless finish: `createGraduatedPool(token)` if phase Swept / auto-grad failed. Reverts `WrongGraduationPhase` if not waiting.

## Launch record and routing

```ts
// getLaunchedToken(token) → LaunchedToken {
//   token, curve, deployer, creatorFeeRecipient, pairToken,
//   graduationThreshold, poolFee, tickSpacing, creatorTaxBps,
//   buybackEnabled, phase, sweptQuote, sweptTokens, sweptAt, exists
// }
// phase: 0 NotGraduated | 1 Swept | 2 PoolCreated | 3 Rescued
```

**Always route by `phase`.** Do not infer from balances alone.

## Curve state / price

```ts
// getReserves() → (quoteReserve, tokenReserve)  // quote includes phantom
// realQuoteReserve(), graduationThreshold(), sellableTokens()
// readyToGraduate(), graduated()
// price ≈ quoteReserve / tokenReserve
// progress ≈ realQuoteReserve / graduationThreshold
```

Reserved for pool:

```text
supply × phantomQuote / (phantomQuote + threshold)
```

## Fees

Pre-grad (on curve): `feeBps()`, `creatorTaxBps()` — total cost bps = sum.

Policy (factory): `getLaunchFeePolicy(token)` → protocol recipient/share, buyback bps, hook fee bps, max internal price impact bps.

Escrow claims:

```ts
// balanceOf(recipient) / claim()
// balanceOfToken(recipient, token) / claimToken(token)
// transferCreatorFeeRecipient(token, newRecipient)  // only current recipient
```

## Buyback vault

```ts
// totalLocked, totalReleased, vestedAmount, releasable, vestingStart
// VESTING_DURATION  // five years
// release(token) → released  // permissionless; credits escrow
```

`vestingStart` is **weighted** and moves with new buybacks — progress from live start, not launch date.

## Events to index

| Event | Where | Purpose |
|-------|-------|---------|
| `TokenLaunched` | Factory | New launch + curve + pair + config + threshold |
| `CurveBuy` / `CurveSell` | Curve | Trades + fees |
| `CurveBuyRefunded` | Curve | Clamped final buy refund |
| `CurveCompleted` | Curve | Curve closed |
| `LaunchSwept` | Factory | Entered swept phase |
| `PoolGraduated` | Factory | Pool created + locked |
| `PoolRegistered` | Hook | Pool known to hook |
| `FeesSwept` / `PoolFeesSwept` | Curve / hook | Fee splits |
| `CreatorFeeRecipientChangeProposed` | Factory | CTO timelock |
| `CreatorFeeRecipientUpdated` | Factory | Payout changed |
| `Credited` / `Claimed` | Escrow | Native payouts |
| `CreditedToken` / `ClaimedToken` | Escrow | ERC-20 / vest payouts (**must index**) |
| `BuybackLocked` | Curve | Buyback executed |
| `Locked` / `Released` | Vault | Vest accounting |
| `AutoGraduationFailed` | Curve | Work queue for `createGraduatedPool` |
| `PoolConversionSkipped` / `PoolBuybackSkipped` | Hook | Soft-fail sweeps |

Example factory launch event (docs):

```text
event TokenLaunched(
  address indexed token,
  address indexed curve,
  address indexed deployer,
  address pairToken,
  uint256 launchConfigId,
  uint256 graduationThreshold
)
```

## Uniswap V4 pool key

```ts
// Sort currencies by address; native ETH (0x0) is always currency0 if present
// poolKey = { currency0, currency1, fee: launch.poolFee /* 0 */, tickSpacing, hooks: memeHook }
// poolId = keccak256(abi.encode(currency0, currency1, fee, tickSpacing, hooks))
// hook.pendingFees(poolId, currency) / pendingCreatorTax(...)
// hook.launches(poolId) → memecoin, quote, sides, recipients, live rates
```

Core pool fee is zero; hook charges and splits under launch policy. Unrelated pools cannot attach to the hook.

## Errors (user-facing)

| Error | Meaning |
|-------|---------|
| `SlippageExceeded` | minOut not met |
| `CurveGraduated` | Use V4 pool |
| `LaunchEconomicsMismatch` | Re-pin economics |
| `PairTokenNotApproved` | Quote not allowed |
| `PairTokenDecimalsMismatch` | Decimals vs recorded |
| `NativeValueMismatch` | value ≠ quoteIn |
| `UnexpectedNativeValue` | value on ERC-20 launch |
| `LaunchFeeNotPaid` | Wrong launch fee |
| `CreatorTaxTooHigh` | Above cap |
| `NotWhitelisted` | Launch restricted |
| `TimelockNotElapsed` / `TimelockExpired` | CTO timing |
| `LaunchConfigDisabled` | Config not open |
| `NotCreatorFeeRecipient` | Unauthorized redirect |
| `WrongGraduationPhase` | Pool create when not swept |

## Safety notes for integrators

- Treat v2 as **unaudited** until reports publish.
- Do not ship production bots against unpublished addresses.
- Report vulns privately to contact@ponsfamily.com.
