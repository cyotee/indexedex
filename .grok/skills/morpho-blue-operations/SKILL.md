---
name: morpho-blue-operations
description: This skill should be used when the user asks about "Morpho supply", "Morpho borrow", "supplyCollateral", "repay", "liquidate Morpho", "createMarket", "Morpho flash loan", "onBehalf Morpho", "position shares", or needs to implement or call Morpho Blue market operations as an end user or integrator.
license: MIT
---

# Morpho Blue Operations

End-user and integrator flows against the Morpho Blue singleton (`IMorpho`).

## Prerequisites

1. Know `MarketParams` for the market (or create one).
2. Hold/approve the relevant ERC-20s for the Morpho address.
3. For borrow: sufficient collateral at market LLTV and oracle price.

## Quick start (EOA / contract)

```solidity
import {IMorpho, MarketParams, Id} from "@crane/contracts/external/morpho/blue/interfaces/IMorpho.sol";
import {MarketParamsLib} from "@crane/contracts/external/morpho/blue/libraries/MarketParamsLib.sol";

using MarketParamsLib for MarketParams;

IMorpho morpho = IMorpho(ETHEREUM_MAIN.MORPHO);
MarketParams memory mp = /* known params */;
Id id = mp.id();

// Lend loan token
loan.approve(address(morpho), amount);
morpho.supply(mp, amount, 0, msg.sender, "");

// Post collateral + borrow
collateral.approve(address(morpho), collAmount);
morpho.supplyCollateral(mp, collAmount, msg.sender, "");
morpho.borrow(mp, borrowAmount, 0, msg.sender, msg.sender);

// Repay (assets) or repay (shares) — one of assets/shares must be 0
loan.approve(address(morpho), type(uint256).max);
morpho.repay(mp, 0, borrowShares, msg.sender, "");
```

## Operation cheat sheet

| Action | Call | Notes |
|--------|------|--------|
| Create market | `createMarket(params)` | IRM + LLTV must be enabled |
| Supply loan | `supply(params, assets, shares, onBehalf, data)` | Exactly one of assets/shares non-zero |
| Withdraw loan | `withdraw(params, assets, shares, onBehalf, receiver)` | Same assets/shares rule |
| Post collateral | `supplyCollateral(params, assets, onBehalf, data)` | |
| Pull collateral | `withdrawCollateral(params, assets, onBehalf, receiver)` | Position must stay healthy if debt |
| Borrow | `borrow(params, assets, shares, onBehalf, receiver)` | Needs authorization if not self |
| Repay | `repay(params, assets, shares, onBehalf, data)` | |
| Liquidate | `liquidate(params, borrower, seizedAssets, repaidShares, data)` | |
| Accrue | `accrueInterest(params)` | Updates market totals |
| Flash loan | `flashLoan(token, assets, data)` | Callback `onMorphoFlashLoan` |
| Auth | `setAuthorization` / `setAuthorizationWithSig` | For `onBehalf` ops |

## Health & liquidation (intuition)

- Collateral value from `oracle.price()` (1e36 scale) × collateral amount.
- Max borrow ≈ collateral value × LLTV (see Blue math / liquidate incentive constants).
- Liquidators seize collateral and repay debt shares/assets in one call.

## Authorization model

- You can always manage **your own** position.
- Others need `isAuthorized(authorizer, operator) == true` (or sig) for `onBehalf` supply/borrow/repay/withdraw.

## Crane-assisted path

Prefer `MorphoBlueService` when the **calling contract holds tokens** (Diamond/strategy):

```solidity
import {MorphoBlueService} from "@crane/contracts/protocols/lending/morpho/blue/services/MorphoBlueService.sol";

(uint256 assets, uint256 shares) =
    MorphoBlueService._supply(morpho, marketParams, amount, address(this));
```

Library code runs in the caller’s context — `safeApprove` applies to the Diamond, not a pranked EOA.

## Navigation

| Topic | File |
|-------|------|
| Full lifecycle example | `references/lifecycle.md` |
| Views & balances libs | `references/views-and-math.md` |
| Liquidation notes | `references/liquidation.md` |
| Crane TestBase / Service | `skill:crane-morpho` |
| Architecture | `skill:morpho-architecture` |

## Key files

- `@crane/contracts/external/morpho/blue/interfaces/IMorpho.sol`
- `@crane/contracts/external/morpho/blue/Morpho.sol`
- `@crane/contracts/protocols/lending/morpho/blue/services/MorphoBlueService.sol`
- Upstream-ported tests: `test/foundry/spec/protocols/lending/morpho/blue/upstream/`

## See also

- `skill:morpho-vaults` — deposit into MetaMorpho instead of raw Blue
- `skill:crane-morpho` — hermetic/fork testing patterns
