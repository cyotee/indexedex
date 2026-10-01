# Uniswap FullSpread Standard Exchange vaults

The **UniswapV3FullSpreadStandardExchangeVault** and **UniswapV4FullSpreadStandardExchangeVault** packages deploy independent vault diamonds. The preserved implementations under `contracts/protocols/dexes/uniswap/v3` and `v4` remain unchanged. They are not deprecated by this work and remain vulnerable to delivery accounting that treats `reserveOfToken` as free plus deployed assets. This is not an upgrade or migration for immutable live instances.

## Deployment

- [V3 package](v3/UniswapV3FullSpreadStandardExchangeVaultDFPkg.sol) and [FactoryService](v3/UniswapV3FullSpreadStandardExchangeVault_Component_FactoryService.sol).
- [V4 package](v4/UniswapV4FullSpreadStandardExchangeVaultDFPkg.sol) and [FactoryService](v4/UniswapV4FullSpreadStandardExchangeVault_Component_FactoryService.sol).
- [Shared constant-product math](StandardExchangeConstantProduct.sol).

Facets and execution delegates use CREATE3; packages deploy through the IndexedEx manager vault registry. Each component/package salt is directly `keccak256(abi.encode("<FullSpread contract name>"))`. Artifact bytecode and constructor arguments remain intact but are not salt inputs. Instance salt derivation, storage field order, and storage slot strings are unchanged.

[VERSION_SOURCE_MAP.json](VERSION_SOURCE_MAP.json) maps preserved source keys to the renamed replacement files. [PRESERVED_SOURCE_SHA256.json](PRESERVED_SOURCE_SHA256.json) and [PRESERVED_BUILD_CONTEXT.json](PRESERVED_BUILD_CONTEXT.json) are unchanged baseline evidence.

## Delivery and reserves

`reserveOfToken(token)` is booked ERC-20 custody **on this diamond**. Vault operations book the final `balanceOf(vault)` for both pool tokens and the self-share, after settlement, refunds, and any automatic rebalance. It excludes deployed liquidity and uncollected fees. On V4 native pools the ERC-20 face is WETH; leftover native ETH is not a public refund balance.

`localReserve` reports the live free sleeve. `deployedReserve()` reads the live position; it is not persisted. Share pricing still uses live free assets, deployed assets, and uncollected fees. TWAP remains the oracle; issuance is not switched to oracle NAV.

Pull routes (`pretransferred=false`) measure this transfer's balance delta and require exact delivery. Fee-on-transfer and rebasing underlying tokens remain forbidden; there is no package token allowlist.

Push is a transfer to the vault followed by `pretransferred=true`. A router can use the user's allowance to transfer directly to the vault and name the user as recipient:

```solidity
token.transferFrom(user, vault, amount);
IStandardExchangeIn(vault).exchangeIn(
    token, amount, IERC20(vault), minShares, user, true, deadline
);
```

No `preparePretransfer` call is used or exposed. The measured pushed input is `balanceOf(vault) - reserveOfToken(token)` captured before settlement changes balances. Exact-in credits exactly `amountIn` when unbooked availability is sufficient. An exact-in excess push does not revert merely for being excess, and exact-in never refunds. A short push reverts `TransferDeltaInsufficient`.

`exchangeOut` requires `used <= max`. False-flag exact-out and dual exits pull the quoted used amount and refund nothing. They do not pull max, a quote buffer, or max shares. True-flag exact-out refunds only `credit - used` to `msg.sender`. Booked inventory cannot fund refunds.

Single-output exact-out share exits burn only used shares directly from the caller without share allowance.

Unsolicited transfers on a live vault are donor risk: unbooked surplus can count as a later caller's delivery. An exact-in call whose declared amount differs from that surplus reverts. This does not permit spending inventory already booked by a vault operation.

## Activation and ownership

Every two-token or NFT-import activation subtracts a shared decimal-scaled minimum from raw `mulSqrt(amount0, amount1)`:

```text
mean = floor((uint256(decimals0) + uint256(decimals1)) / 2)
MINIMUM_LIQUIDITY = mean < 3 ? 1 : 10 ** (mean - 3)
caller shares = raw - MINIMUM_LIQUIDITY
```

The examples are 18/18 → `1e15`, 6/18 → `1e9`, 6/6 → `1e3`, and 6/9 → `1e4`. A failing decimals call falls back to 18 for that token. `raw <= minimum` reverts `InsufficientMinimumLiquidity(raw, minimum)`. The minimum is minted once to `address(0xdEaD)`; pre-existing inventory additionally receives residual sink shares calculated from caller-issued shares. Previews mint nothing. Single-token activation remains invalid.

Imports issue shares only for assets collected from the NFT, excluding the existing sleeve. V3 retains its import preview; V4 adds no import-preview API. Both retain the empty NFT in vault custody. V4 has no imported-increase path and grants no ERC-20 or Permit2 approval to the Position Manager. Existing Permit2/PoolManager approvals for organic settlement remain.

## Native SY, sleeves, and exits

The vault's native SY external redemption transfers the caller's shares internally without allowance, then follows the measured push route. Internal-balance redemption uses the fixed proxy self-call with `pretransferred=false`: only the active Native SY context can credit the diamond's requested self-share amount. Settlement burns it once. Insufficient self-balance reverts with the exact requested and available amounts; context is restored on success or failure.

Disabling a vault or package blocks inbound pool-token routes while allowing existing share exits and SY redemptions.

`rebalanceLiquidReserve()` remains permissionless, pays its caller nothing, and preserves the fee-oracle sleeve target, rounding, and dust policy. It never swaps. A 0% sleeve can block locked exits; a positive target also does not guarantee capacity for every withdrawal.

Idle exits withdraw the proportional liquidity and convert the other asset through the underlying pool. Locked exits use the full live share book for constant-product valuation but pay only from the available local sleeve. On an independent 1000/1000 book with a 20% sleeve, 10% and 1% supply burns quote approximately 190 and 19.9 output tokens respectively. Insufficient capacity reverts atomically. Ordinary paid AMM arbitrage remains possible.

## Validation scope

The final local gate passed 654 tests across 49 suites, including 12,288 invariant operations with zero unexpected reverts. All 26 deployed runtimes fit the release limit; all 96 preserved-source hashes match.

See [VALIDATION.md](VALIDATION.md), [REGRESSION_RESULTS.txt](REGRESSION_RESULTS.txt), and [VALIDATED_ARTIFACTS.json](VALIDATED_ARTIFACTS.json) for execution evidence. Build artifacts before tests using `scripts/forge-artifacts.py`; the [implementation plan](uniswap-se-v2-liquidity-leak-fixes.plan.md) gives the complete renamed-source command and preservation checks. Default hermetic profile; no `via_ir`; every deployed facet, delegate, and package must fit 24,576 runtime bytes.

Native SY on these vaults is in scope. DETF, Pendle markets/external SY wrappers, arbitrary consuming hooks, and live instances are not covered. CP-09 consuming-hook integration remains open. CP-07 Robinhood replay remains historical and is not rerun here.
