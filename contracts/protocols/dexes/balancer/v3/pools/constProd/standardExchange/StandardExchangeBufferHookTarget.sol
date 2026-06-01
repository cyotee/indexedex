// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.0;

import {IHooks} from
    "@crane/contracts/external/balancer/v3/interfaces/contracts/vault/IHooks.sol";
import {
    HookFlags,
    TokenConfig,
    TokenType,
    LiquidityManagement,
    PoolSwapParams,
    AfterSwapParams,
    AddLiquidityKind,
    RemoveLiquidityKind
} from "@crane/contracts/external/balancer/v3/interfaces/contracts/vault/VaultTypes.sol";

import {IStandardExchangeBufferPool} from
    "contracts/protocols/dexes/balancer/v3/pools/constProd/standardExchange/IStandardExchangeBufferPool.sol";
import {StandardExchangeBufferPoolRepo as Repo} from
    "contracts/protocols/dexes/balancer/v3/pools/constProd/standardExchange/StandardExchangeBufferPoolRepo.sol";

/**
 * @title StandardExchangeBufferHookTarget
 * @notice Abstract hook target implementing IHooks for the StandardExchangeBufferPool.
 * @dev Abstract because `_balancerV3Vault()` and `_expectedFactory()` are left virtual
 *      for the facet (Task 12) to provide. This slice covers registration + initialization.
 *      Swap and LP hooks are filled in by Tasks 8-11.
 */
abstract contract StandardExchangeBufferHookTarget is IHooks {

    /* ----- Virtual hooks (resolved by the facet) ----- */

    /// @dev Returns the Balancer V3 Vault address. Implemented by the facet.
    function _balancerV3Vault() internal view virtual returns (address);

    /// @dev Returns the expected pool factory address. Implemented by the facet.
    function _expectedFactory() internal view virtual returns (address);

    /* ----- Registration ----- */

    /**
     * @notice Returns the set of hooks this contract implements.
     * @return hookFlags Flags indicating which hooks are active.
     */
    function getHookFlags() external pure virtual override returns (HookFlags memory) {
        return HookFlags({
            enableHookAdjustedAmounts: false,
            shouldCallBeforeInitialize: true,
            shouldCallAfterInitialize: false,
            shouldCallComputeDynamicSwapFee: false,
            shouldCallBeforeSwap: true,
            shouldCallAfterSwap: true,
            shouldCallBeforeAddLiquidity: true,
            shouldCallAfterAddLiquidity: true,
            shouldCallBeforeRemoveLiquidity: false,
            shouldCallAfterRemoveLiquidity: true
        });
    }

    /**
     * @notice Hook executed when a pool is registered with this hook contract.
     * @dev Validates: msg.sender is Vault, factory matches expected, pool is this contract,
     *      tokenConfig has exactly 2 entries with correct types and rate provider, and all
     *      required LiquidityManagement flags are set.
     */
    function onRegister(
        address factory,
        address pool,
        TokenConfig[] memory tokenConfig,
        LiquidityManagement calldata lm
    ) external view virtual override returns (bool) {
        if (msg.sender != _balancerV3Vault()) return false;
        if (factory != _expectedFactory()) return false;
        if (pool != address(this)) return false;
        if (tokenConfig.length != 2) return false;

        uint256 ttaIdx = Repo._ttaIndex();
        uint256 sharesIdx = Repo._sharesIndex();

        if (address(tokenConfig[ttaIdx].token) != address(Repo._ttaToken())) return false;
        if (address(tokenConfig[sharesIdx].token) != address(Repo._shareToken())) return false;
        if (tokenConfig[ttaIdx].tokenType != TokenType.STANDARD) return false;
        if (tokenConfig[sharesIdx].tokenType != TokenType.WITH_RATE) return false;
        if (address(tokenConfig[sharesIdx].rateProvider) != address(Repo._rateProvider())) return false;

        if (!lm.disableUnbalancedLiquidity) return false;
        if (!lm.enableAddLiquidityCustom) return false;
        if (!lm.enableRemoveLiquidityCustom) return false;
        if (!lm.enableDonation) return false;

        return true;
    }

    /* ----- Initialization ----- */

    /**
     * @notice Hook executed before pool initialization.
     * @dev Seeds virtualTTA = s_init * rate / 1e18, and resets hookSharesDelta to 0.
     *      Reverts if the rate provider returns zero or the resulting virtualTTA is zero.
     */
    function onBeforeInitialize(uint256[] memory exactAmountsIn, bytes memory)
        external virtual override returns (bool)
    {
        if (msg.sender != _balancerV3Vault()) return false;
        uint256 sharesIdx = Repo._sharesIndex();
        uint256 sInitRaw = exactAmountsIn[sharesIdx];
        uint256 rate = Repo._rateProvider().getRate();
        if (rate == 0) revert IStandardExchangeBufferPool.RateProviderZero();
        // Assumes 18-decimal share token; multi-decimal handling added if needed.
        uint256 virtualInit = (sInitRaw * rate) / 1e18;
        if (virtualInit == 0) revert IStandardExchangeBufferPool.InitialInvariantTooSmall();
        Repo._setVirtualTTA(virtualInit);
        Repo._setHookSharesDelta(0);
        return true;
    }

    /* ----- Stubs for remaining IHooks methods (filled in Tasks 8-11) ----- */

    /// @dev Not used (shouldCallAfterInitialize = false). Returns false.
    function onAfterInitialize(uint256[] memory, uint256, bytes memory)
        external virtual override returns (bool)
    {
        return false;
    }

    /// @dev Active hook — implementation in Task 8.
    function onBeforeAddLiquidity(
        address,
        address,
        AddLiquidityKind,
        uint256[] memory,
        uint256,
        uint256[] memory,
        bytes memory
    ) external virtual override returns (bool) {
        revert("unimplemented");
    }

    /// @dev Active hook — implementation in Task 9.
    function onAfterAddLiquidity(
        address,
        address,
        AddLiquidityKind,
        uint256[] memory,
        uint256[] memory,
        uint256,
        uint256[] memory,
        bytes memory
    ) external virtual override returns (bool, uint256[] memory) {
        revert("unimplemented");
    }

    /// @dev Not used (shouldCallBeforeRemoveLiquidity = false). Returns false.
    function onBeforeRemoveLiquidity(
        address,
        address,
        RemoveLiquidityKind,
        uint256,
        uint256[] memory,
        uint256[] memory,
        bytes memory
    ) external virtual override returns (bool) {
        return false;
    }

    /// @dev Active hook — implementation in Task 10.
    function onAfterRemoveLiquidity(
        address,
        address,
        RemoveLiquidityKind,
        uint256,
        uint256[] memory,
        uint256[] memory,
        uint256[] memory,
        bytes memory
    ) external virtual override returns (bool, uint256[] memory) {
        revert("unimplemented");
    }

    /// @dev Active hook — implementation in Task 11.
    function onBeforeSwap(PoolSwapParams calldata, address)
        external virtual override returns (bool)
    {
        revert("unimplemented");
    }

    /// @dev Active hook — implementation in Task 11.
    function onAfterSwap(AfterSwapParams calldata)
        external virtual override returns (bool, uint256)
    {
        revert("unimplemented");
    }

    /// @dev Not used (shouldCallComputeDynamicSwapFee = false). Returns (false, 0).
    function onComputeDynamicSwapFeePercentage(PoolSwapParams calldata, address, uint256)
        external view virtual override returns (bool, uint256)
    {
        return (false, 0);
    }
}
