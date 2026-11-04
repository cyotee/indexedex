# Deploy path: Package → Vault Registry → Hook Factory

## Contents

- Bootstrap (once)
- Package registration
- Typed `deployVault` on the package
- Mining
- ACL
- Discovery after deploy

## Bootstrap (once per chain / test env)

1. CREATE3-deploy hook factory via  
   `UniswapV4HookDiamondPackageCallBackFactory_FactoryService.deployUniswapV4HookDiamondPackageCallBackFactory`.
2. InitArgs: reuse canonical ERC165 / Loupe / ERC8109 / PostDeploy from Create3 facet registry; CREATE3-deploy `UniswapV4HookFlagsFacet`.
3. Owner/operator:

```solidity
IVaultRegistryDeployment(manager).setHookDiamondPackageFactory(address(hookFactory));
```

Without this, `deployHookVault` reverts (`ZeroAddress` on unset factory).

## Package registration

Hook DFPkgs are vault packages for discovery:

```solidity
vm.prank(owner);
address pkg = IVaultRegistryDeployment(manager).deployPkg(
    type(MyHookPackage).creationCode,
    abi.encode(IMyHookPackage.PkgInit({ /* facets, registry, ... */ })),
    salt
);
```

Package constructor typically stores `IVaultRegistryDeployment` (immutable), same as SE packages store registry for `deployVault`.

## Typed package helper (required product surface)

Mirror SE packages: **package enumerates args**, registry deploys + registers.

```solidity
// On IMyHookPackage (PkgArgs on interface)
function deployVault(PkgArgs memory args, uint256 mineNonce) external returns (address vault);

// Implementation
function deployVault(PkgArgs memory args, uint256 mineNonce) public returns (address vault) {
    vault = VAULT_REGISTRY_DEPLOYMENT.deployHookVault(
        IStandardVaultPkg(address(SELF)),
        abi.encode(args),
        mineNonce
    );
}
```

Optional: `deployVaultAutoMine(args)` → `deployHookVaultAutoMine` (gas-risky; hermetic convenience only).

**Gold reference:**  
`test/foundry/spec/hooks/uniswap/v4/factory/stubs/UniswapV4HookDiamondFactoryStubPackage.sol`

## Mining (production)

```text
processed = processArgs(pkgArgs)     // same as on-chain
packageSalt = calcSalt(processed)
flags = requiredHookFlags() & FLAG_MASK
for mineNonce = 0 .. :
  finalSalt = keccak256(abi.encode(packageSalt, mineNonce))
  addr = create2(factory, PROXY_INIT_HASH, finalSalt)
  if (uint160(addr) & FLAG_MASK) == flags: break
deployVault(args, mineNonce)
```

Helpers: `factory.PROXY_INIT_HASH()`, `previewFinalSalt`, `calcAddress`; pure loop in  
`UniswapV4HookDiamondCreate2Lib` / FactoryService `findMineNonce` (tests/scripts).

## ACL

`deployHookVault` / `deployHookVaultAutoMine` use the same gate as `deployVault`:

- Owner
- Operator (global / function)
- **Registered package** (`msg.sender` is the pkg)

So when users call `pkg.deployVault(...)`, the package is authorized after `deployPkg`.

## After success

- Instance is a vault: `isVault`, `vaultsOfPackage(pkg)`, etc.
- Address has V4 permission flags from package pure flags.
- Instance exposes `requiredHookFlags()` via base HookFlags facet.

## Not the product path

```solidity
// Isolation / emergency only — no registry entry
hookFactory.deployWithMineNonce(pkg, abi.encode(args), mineNonce);

// WRONG — vault factory, package-in-salt, no V4 mining
registry.deployVault(pkg, abi.encode(args));
```
