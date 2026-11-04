# MetaMorpho V1.1 (detail)

## Contents

- Factory create
- Hermetic TestBase
- Deposit path
- Roles checklist

## Factory

```solidity
constructor(address morpho) // immutable MORPHO

function createMetaMorpho(
    address initialOwner,
    uint256 initialTimelock,
    address asset,
    string memory name,
    string memory symbol,
    bytes32 salt
) external returns (IMetaMorphoV1_1);
```

Vault constructor wires `ERC4626(asset)`, `Ownable(owner)`, Morpho immutable.

## Hermetic TestBase

`contracts/protocols/lending/morpho/metamorpho/test/bases/TestBase_MetaMorpho.sol`

Extends `TestBase_MorphoBlue` then:

1. `new MetaMorphoV1_1Factory(morpho)`
2. `createMetaMorpho(OWNER, timelock, loanToken, …)`
3. Owner sets curator + allocator
4. Curator `submitCap` → warp → `acceptCap`
5. Allocator `setSupplyQueue([marketId])`

## End-user deposit asserts

Prefer exact:

```solidity
uint256 preview = vault.previewDeposit(assets);
uint256 shares = vault.deposit(assets, user);
assertEq(shares, preview);
```

Crane lifecycle: `test/foundry/spec/protocols/lending/morpho/metamorpho/unit/MetaMorphoLifecycle.t.sol`.

## Integrator checklist

- [ ] `vault.MORPHO()` is intended Blue instance  
- [ ] Market exists on Blue with correct IRM/LLTV  
- [ ] Cap accepted and market on supply queue  
- [ ] Asset approvals to vault  
- [ ] Timelock understood for governance ops  
- [ ] Fee recipient set if fee > 0  
