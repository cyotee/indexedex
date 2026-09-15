# Uniswap Standard Exchange V2 implementations

New, separately deployed V3 and V4 vault packages. The deployed-reference implementations remain under `contracts/protocols/dexes/uniswap/v3` and `v4`.

## Entry points and deployment

- V3 package: [`UniswapV3StandardExchangeDFPkgV2`](v3/UniswapV3StandardExchangeDFPkgV2.sol), assembled by [`UniswapV3_Component_FactoryServiceV2`](v3/UniswapV3_Component_FactoryServiceV2.sol).
- V4 package: [`UniswapV4StandardExchangeDFPkgV2`](v4/UniswapV4StandardExchangeDFPkgV2.sol), assembled by [`UniswapV4_Component_FactoryServiceV2`](v4/UniswapV4_Component_FactoryServiceV2.sol).
- Shared delivery: [`StandardExchangeDeliveryRepo`](StandardExchangeDeliveryRepo.sol).
- Shared accounting: [`StandardExchangeConstantProduct`](StandardExchangeConstantProduct.sol).

All versioned Solidity declarations and artifact IDs have a `V2` suffix. FactoryServices use those artifacts and separate release-salt namespaces. They deploy facets through CREATE3 and register packages through the manager's vault registry. The existing generic SE selectors remain installed; the In facet additionally exposes `IStandardExchangePretransfer` through the actual package cuts and ERC-165 declarations.

Storage layouts retain their field order and slot names on **new, independent diamonds**. These files are not an upgrade recipe for immutable old instances. [VERSION_SOURCE_MAP.json](VERSION_SOURCE_MAP.json) enumerates old/new files; [PRESERVED_SOURCE_SHA256.json](PRESERVED_SOURCE_SHA256.json) covers all 96 preserved files. [PRESERVED_BUILD_CONTEXT.json](PRESERVED_BUILD_CONTEXT.json) records the comparison build context.

## Integration change: prepared push inputs

Approval-and-pull calls (`pretransferred=false`) retain their entry-point arguments. Token delivery must equal the requested amount; fee-on-transfer inputs are rejected.

A push caller must now perform the following **atomically in one transaction, from the same caller contract**:

```solidity
bytes memory callData = abi.encodeCall(
    IStandardExchangeIn.exchangeIn,
    (token, amount, vaultShare, minShares, recipient, true, deadline)
);
// tokens/amounts contain the exact fresh inputs of this exchange call.
IPretransfer(vault).preparePretransfer(tokens, amounts, keccak256(callData));
token.safeTransfer(vault, amount);
(bool ok, bytes memory result) = vault.call(callData);
if (!ok) assembly ("memory-safe") { revert(add(result, 32), mload(result)) }
```

The preparation supports one or two distinct pool-token ERC20 faces, or vault shares. For an exact-output call, prepare and deliver the full `maxAmountIn`; unused verified input is refunded to the caller. For multi-input calls, prepare both tokens. Native V4 currency uses **WETH** as its ERC20 input face, just as the existing exchange API does.

The commitment binds the caller and complete calldata, including recipient, limit, deadline and trust flag. All delivered amounts are checked before route execution, consumed once, and cleared on success. Unused credits revert the entire exchange. A pending preparation blocks interleaved economic operations on that vault. Transient storage clears unfinished preparation at transaction end. Do not split preparation, transfer, and exchange into separate wallet transactions or catch an exchange failure while retaining a completed transfer; EOAs should use approval-and-pull.

**Existing push-only routers/hooks must add this preparation step before using the new vaults.** Their old transfer-then-call sequence is deliberately rejected. Pull integrations retain their calling convention. The regression suite exercises valid prepared routes inside real V3 flash callbacks and V4 outer unlock sessions. Both versions require the chain's existing EIP-1153 support (the inherited reentrancy lock already uses transient storage).

## Liquidity and ownership rules

Both versions use the same shared deposit calculations: two-token activation, proportional subsequent two-token issuance, and fee-free same-book single-token zap issuance. A two-token contribution follows the V2-pair convention: the limiting contribution determines shares, and any surplus stays as a donation. Integrators should supply the desired ratio or explicitly accept that surplus; no unrelated vault inventory funds refunds.

When the underlying pool can be used, a single-token withdrawal removes the holder's proportional position and local balances, then converts the other token through the real underlying pool, paying that pool's fees and price impact. When pool interaction is blocked, the local sleeve instead settles a fee-free constant-product exchange against the remaining complete vault book. This includes both token entitlements; the remaining holders retain the other token. Output must be fully covered by local custody. Exact-output shares invert the same integer forward quote and round up. A blocked single-token exit cannot burn the entire supply while leaving another backing asset behind.

Previews and projected inventory transitions use the same blocked-settlement functions. Reserve synchronization now follows single-token payouts. `rebalanceLiquidReserve()` remains add/remove-only, reads the existing fee-oracle configuration, and never swaps.

These rules do not price shares by external oracle NAV. Different external-pool and complete-book prices can still produce ordinary AMM arbitrage.

## Validation

Run from the repository root:

```sh
python3 scripts/forge-artifacts.py test \
  contracts/vaults/standard/exchange/protocols/uniswap/StandardExchangeDeliveryRepo.sol \
  contracts/vaults/standard/exchange/protocols/uniswap/StandardExchangeConstantProduct.sol \
  --test-root test/foundry/spec/vaults/standard/exchange/protocols/uniswap/remediation
```

The script rebuilds implementation and runtime artifacts before executing the selected tests. See [VALIDATION.md](VALIDATION.md) for the recorded results and scope.
