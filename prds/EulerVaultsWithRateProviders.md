# Product Requirements Document (PRD): Rate Provider-Enhanced Euler Vaults

## 1. Overview

### Product Name
RateProviderEulerVault (and factory/template for deploying enhanced versions of existing Euler vaults)

### Purpose
Develop a customizable extension to Euler v2's Euler Vault Kit (EVK) that introduces support for a **configurable Rate Provider** in the Interest Rate Model (IRM). This allows existing Euler vault types (e.g., standard linear-kink IRM vaults) to be replicated with enhanced handling of yield-bearing underlyings—specifically, tokens that implement an external `getRate()` scaling factor (e.g., Balancer vault tokens, Aura rewards wrappers, or any ERC-4626 with external accrual).

The core innovation: Adjust effective utilization and rate calculations by querying a Rate Provider, enabling accurate reflection of underlying value growth **outside** the vault (e.g., staking rewards, external yield) while preserving Euler's native utilization-driven interest mechanics.

This creates "drop-in" enhanced versions of popular Euler vaults, improving composability with Balancer/Aura ecosystems and enabling better nesting/meta-vaults.

### Key Goals
- Replicate behavior of existing Euler vaults (e.g., default Kink IRM curves) exactly when no Rate Provider is set.
- Seamlessly integrate Balancer-style Rate Providers for scaled utilization/rates.
- Permissionless deployment via EVK-compatible factory.
- Maintain ERC-4626 compliance and full Euler v2 compatibility (EVC, oracles, hooks).
- Enable high-precision lending on yield-bearing assets without rebasing issues.

### Scope
- Custom IRM with Rate Provider support.
- Vault factory/template deploying enhanced vaults (mirroring existing configs like WETH/USDC markets).
- No changes to core Euler protocols (EVC/EVK)—pure extension.
- Target: Ethereum mainnet + L2s where Euler v2 is deployed.

## 2. Background & Rationale
Euler v2 vaults use utilization-based IRMs internally. For yield-bearing underlyings (non-rebasing), external accrual isn't natively factored into rates/utilization—leading to suboptimal pricing.

Balancer/Aura tokens use `getRate()` to expose scaling. By incorporating this into a custom IRM:
- Effective assets = cash * rateProvider.getRate() / 1e18
- Utilization adjusted accordingly → rates reflect true economic value.
- Replicates standard Euler curves (via configurable params) for backward compatibility.

This unlocks lending markets for boosted pools, staked tokens, etc., with accurate yield pass-through.

## 3. Features & Requirements

### Core Features
1. **Configurable Rate Provider IRM**
   - Implements `IInterestRateModel`.
   - Constructor/factory params: Standard curve settings (baseRate, multiplier, kinkUtil, jumpMultiplier) + optional `address rateProvider`.
   - In `computeInterestRate`:
     - If rateProvider == address(0): Pure standard Euler calculation.
     - Else: Scale cash/totalAssets by `getRate()`, compute adjusted utilization, apply curve.
   - Support negation/scaling direction (e.g., for borrow-side if needed).

2. **Enhanced Vault Template**
   - ERC-4626 vault using the new IRM.
   - Deployment factory: Mirrors Euler's existing vault creation (unit of account, oracle, governor).
   - Configurable: Attach standard or RateProvider IRM instance.

3. **Backward Compatibility**
   - Deployed vaults behave identically to official Euler vaults when rateProvider unset.
   - Full EVC integration (collateral/debt batching).

4. **Views & Monitoring**
   - Add view functions: `effectiveUtilization()`, `scaledTotalAssets()` for transparency.

### Non-Goals
- Support rebasing tokens (explicitly banned in Euler).
- Modify core EVK/EVC.
- Built-in governance—use external governor or Euler's.

## 4. Technical Design

### Custom IRM Pseudocode
```solidity
interface IRateProvider {
    function getRate() external view returns (uint256);
}

contract RateProviderIRM is IInterestRateModel {
    address public immutable rateProvider;
    // Standard kink params (configurable)
    uint256 public baseRate;
    uint256 public multiplier;
    uint256 public kinkUtil;
    uint256 public jumpMultiplier;

    constructor(address _rateProvider, uint256 _baseRate, ...) {
        rateProvider = _rateProvider;
        // Set params to match existing Euler IRMs
    }

    function computeInterestRate(address vault, uint256 cash, uint256 borrows) external view returns (uint256) {
        uint256 scaling = rateProvider == address(0) ? 1e18 : IRateProvider(rateProvider).getRate();

        uint256 adjustedCash = cash * scaling / 1e18;
        uint256 total = adjustedCash + borrows;
        uint256 util = total == 0 ? 0 : borrows * 1e18 / total;

        // Standard kink logic on adjusted util
        if (util <= kinkUtil) {
            return baseRate + (util * multiplier / 1e18);
        } else {
            return baseRate + (kinkUtil * multiplier / 1e18) + ((util - kinkUtil) * jumpMultiplier / 1e18);
        }
    }
}
```

### Deployment Flow
- Deploy IRM instances (factory for param variations, matching official Euler configs).
- Use EVK factory to create vault with custom IRM.
- Optional: Periphery router for "createEnhancedVault" with rateProvider param.

## 5. Safety & Risks
- **Oracle/External Call Risk**: Rate Provider trusted—document only verified (e.g., Balancer official).
- **Scaling Extremes**: Test edge cases (rate >>/< 1e18).
- **Gas**: Extra call (~5-10k gas)—acceptable.
- **Audits**: Recommend formal review for custom IRM.

## 6. Task Breakdown

### Phase 1: Research & Setup (2-3 days)
1. Fork/submodule Euler repos (EVC, EVK, price-oracle, periphery).
2. Review existing IRM implementations (match params exactly).

### Phase 2: Custom IRM Development (4-5 days)
3. Implement RateProviderIRM contract.
4. Factory for parameterized deployments.
5. Unit tests: Standard mode vs scaled mode, edge rates.

### Phase 3: Vault Integration (3-4 days)
6. Enhanced vault template/factory.
7. Deployment scripts (match popular markets, e.g., WETH vault with Balancer wstETH Rate Provider).

### Phase 4: Testing & Validation (5-7 days)
8. Foundry fork tests: Deploy cluster, simulate deposits/borrows with scaling.
9. Compare rates/util vs official Euler vaults.
10. Gas benchmarking.

### Phase 5: Documentation & Polish (2 days)
11. README/deployment guide.
12. Example: Enhanced vault for Balancer/Aura pool.

Total: 3-4 weeks for a senior Solidity dev.

This delivers reusable, enhanced Euler vaults—bridging Balancer composability into lending. Prioritize matching the most popular existing Euler IRM (e.g., default adaptive/kink) for quick adoption. Review against latest EVK for compatibility.