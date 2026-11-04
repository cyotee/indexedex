# Salt, flags, and immutability

## Contents

- Salt law (P19)
- What goes in `calcSalt`
- Flags and mining
- Instance HookFlags storage
- Immutability (install-then-remove)
- First-deployer-wins

## Salt law (normative)

Factory **always**:

```text
processedArgs = processArgs(pkgArgs)
packageSalt   = calcSalt(processedArgs)   // package view; no package address
finalSalt     = keccak256(abi.encode(packageSalt, mineNonce))
```

**Never** mix `address(pkg)` into salt (unlike vault `DiamondPackageCallBackFactory`).

Off-chain miners must apply the **same** `processArgs` rules as on-chain before `calcSalt`.

## What goes in `calcSalt`

| Include | Exclude |
|---------|---------|
| Stable `PRODUCT_ID` (bytes32 name hash) | Package contract address |
| Binding: poolManager, SE vaults, tokens, feeOracle, threshold mode, etc. | Facet addresses that change on logic redeploy (unless intentional) |
| Fields that define the immortal instance identity | Ephemeral deploy-time noise |

Same PRODUCT_ID + args → same predicted address even if package code is redeployed at a new address.

## Flags and mining

- Source: `requiredHookFlags() external pure returns (uint160)` — **package-constant** (not PkgArgs-dependent).
- Factory masks with `Hooks.ALL_HOOK_MASK` (bottom 14 bits).
- `MAX_LOOP = 160_444` (HookMiner peer); exhaustion → `HookMineExhausted`.
- Premine: `deployWithMineNonce` validates flags or reverts `InvalidHookFlags`.
- Auto-mine: `deploy` loops from nonce 0 — **gas-risky**; not the production UX.

`requiredHookFlags() == 0` is allowed for non-hook diamonds using this factory.

## Instance flags surface

Factory base-cuts `UniswapV4HookFlagsFacet` and writes flags in `initAccount` via `UniswapV4HookFlagsRepo`.

Integrators read `IUniswapV4HookFlags(proxy).requiredHookFlags()` without knowing the package address.

## Immutability

Base cuts on every proxy: ERC165, Loupe, ERC8109, temporary PostDeploy, HookFlags.

- Init uses `ERC2535Repo._processFacetCuts` (no diamondCut facet required for install).
- Packages **must not** add `diamondCut` in `diamondConfig`.
- After deploy, factory `postDeploy` removes PostDeploy selectors.
- Live instance: no callable `diamondCut`. Bad config → abandon instance; new binding / new salt.

## First-deployer-wins

If predicted address already has code:

1. Flags already validated for this salt.
2. `pkg.isExpectedInstance(proxy, processedArgs)`.
3. `true` → return existing (no second `HookDiamondDeployed`).
4. `false` → `HookDeployCollision`.

**Thin `isExpectedInstance` (v1 / stub):**

```solidity
return proxy.code.length > 0
    && (uint160(proxy) & FLAG_MASK) == (requiredHookFlags() & FLAG_MASK);
```

Do **not** require loupe/facet-set equality (would block intentional package-address swap at same PRODUCT_ID).

## Constants

```text
PROXY_INIT_HASH = keccak256(type(MinimalDiamondCallBackProxy).creationCode)
FLAG_MASK       = Hooks.ALL_HOOK_MASK
MAX_LOOP        = 160_444
```

Public getters on factory for off-chain tools.
