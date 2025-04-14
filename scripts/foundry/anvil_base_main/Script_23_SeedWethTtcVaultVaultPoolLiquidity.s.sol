// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.0;

import {DeploymentBase} from "./DeploymentBase.sol";

/* -------------------------------------------------------------------------- */
/*                                OpenZeppelin                                */
/* -------------------------------------------------------------------------- */

import {IERC20} from "@crane/contracts/interfaces/IERC20.sol";
import {IUniswapV2Pair} from "@crane/contracts/interfaces/protocols/dexes/uniswap/v2/IUniswapV2Pair.sol";
import {IPool} from "@crane/contracts/interfaces/protocols/dexes/aerodrome/IPool.sol";

/* -------------------------------------------------------------------------- */
/*                                   Crane                                    */
/* -------------------------------------------------------------------------- */

import {IERC20MintBurn} from "@crane/contracts/interfaces/IERC20MintBurn.sol";
import {IERC4626} from "@crane/contracts/interfaces/IERC4626.sol";

/* -------------------------------------------------------------------------- */
/*                                 Balancer                                   */
/* -------------------------------------------------------------------------- */

import {InputHelpers} from "@crane/contracts/external/balancer/v3/solidity-utils/contracts/helpers/InputHelpers.sol";

/* -------------------------------------------------------------------------- */
/*                                 Permit2                                   */
/* -------------------------------------------------------------------------- */

import {IPermit2} from "@crane/contracts/interfaces/protocols/utils/permit2/IPermit2.sol";

/// @title Script_23_SeedWethTtcVaultVaultPoolLiquidity
/// @notice Initializes the Balancer V3 vault-vault pool with equal quantities of both vault shares.
/// @dev Mints LP tokens for both underlying pools, deposits into vaults to get shares,
///      then initializes the Balancer pool with proportional amounts.
contract Script_23_SeedWethTtcVaultVaultPoolLiquidity is DeploymentBase {
    /* ---------------------------------------------------------------------- */
    /*                                 Config                                 */
    /* ---------------------------------------------------------------------- */

    uint256 internal constant MINT_TTC = 2_000_000e18;
    uint256 internal constant MINT_TTA = 2_000_000e18;
    uint256 internal constant MINT_TTB = 2_000_000e18;

    uint256 internal constant INITIAL_UNDERLYING_WETH = 10e18;
    uint256 internal constant INITIAL_UNDERLYING_TOKEN = 10_000e18;
    uint256 internal constant INITIAL_VAULT_SHARES = 1e18; // Equal quantity for both vaults

    /* ---------------------------------------------------------------------- */
    /*                                  Inputs                                */
    /* ---------------------------------------------------------------------- */

    address private ttA;
    address private ttB;
    address private ttC;

    // Underlying A/B/C pools
    address private abPool;
    address private acPool;
    address private bcPool;
    address private aeroAbPool;
    address private aeroAcPool;
    address private aeroBcPool;

    // Underlying DEX pools
    address private uniWethcPool;
    address private aeroWethcPool;

    // Vaults
    address private uniAbVault;
    address private uniAcVault;
    address private uniBcVault;
    address private aeroAbVault;
    address private aeroAcVault;
    address private aeroBcVault;
    address private uniWethcVault;
    address private aeroWethcVault;

    // Balancer vault-vault pool
    address private balancerAbVaultVaultPool;
    address private balancerAcVaultVaultPool;
    address private balancerBcVaultVaultPool;
    address private balancerWethcVaultVaultPool;

    function run() external {
        _setup();
        _loadPreviousDeployments();

        _logHeader("Stage 23: Seed WETH/TTC Vault-Vault Pool Liquidity");

        vm.startBroadcast();
        _mintAndWrap();
        _approve();
        _seedAllVaultVaultPools();
        vm.stopBroadcast();

        _exportJson();
        _logResults();
    }

    function _loadPreviousDeployments() internal {
        ttA = _readAddress("05_test_tokens.json", "testTokenA");
        ttB = _readAddress("05_test_tokens.json", "testTokenB");
        ttC = _readAddress("05_test_tokens.json", "testTokenC");
        require(ttA != address(0) && ttB != address(0) && ttC != address(0), "Test tokens not found");

        abPool = _readAddress("06_pools.json", "abPool");
        acPool = _readAddress("06_pools.json", "acPool");
        bcPool = _readAddress("06_pools.json", "bcPool");
        aeroAbPool = _readAddress("06_pools.json", "aeroAbPool");
        aeroAcPool = _readAddress("06_pools.json", "aeroAcPool");
        aeroBcPool = _readAddress("06_pools.json", "aeroBcPool");

        require(abPool != address(0) && acPool != address(0) && bcPool != address(0), "UniV2 pools missing");
        require(aeroAbPool != address(0) && aeroAcPool != address(0) && aeroBcPool != address(0), "Aerodrome pools missing");

        uniAbVault = _readAddress("07_strategy_vaults.json", "abVault");
        uniAcVault = _readAddress("07_strategy_vaults.json", "acVault");
        uniBcVault = _readAddress("07_strategy_vaults.json", "bcVault");

        aeroAbVault = _readAddress("08_aerodrome_strategy_vaults.json", "aeroAbVault");
        aeroAcVault = _readAddress("08_aerodrome_strategy_vaults.json", "aeroAcVault");
        aeroBcVault = _readAddress("08_aerodrome_strategy_vaults.json", "aeroBcVault");

        require(uniAbVault != address(0) && uniAcVault != address(0) && uniBcVault != address(0), "UniV2 vaults missing");
        require(aeroAbVault != address(0) && aeroAcVault != address(0) && aeroBcVault != address(0), "Aerodrome vaults missing");

        uniWethcPool = _readAddress("17_weth_ttc_pools.json", "uniWethcPool");
        aeroWethcPool = _readAddress("17_weth_ttc_pools.json", "aeroWethcPool");

        uniWethcVault = _readAddress("18_weth_ttc_vaults.json", "uniWethcVault");
        aeroWethcVault = _readAddress("18_weth_ttc_vaults.json", "aeroWethcVault");

        balancerAbVaultVaultPool = _readAddress("22_weth_ttc_vault_vault_pool.json", "balancerAbVaultVaultPool");
        balancerAcVaultVaultPool = _readAddress("22_weth_ttc_vault_vault_pool.json", "balancerAcVaultVaultPool");
        balancerBcVaultVaultPool = _readAddress("22_weth_ttc_vault_vault_pool.json", "balancerBcVaultVaultPool");
        balancerWethcVaultVaultPool = _readAddress("22_weth_ttc_vault_vault_pool.json", "balancerWethcVaultVaultPool");

        require(uniWethcPool != address(0) && aeroWethcPool != address(0), "WETH/TTC pools missing");
        require(uniWethcVault != address(0) && aeroWethcVault != address(0), "WETH/TTC vaults missing");
        require(
            balancerAbVaultVaultPool != address(0) && balancerAcVaultVaultPool != address(0) && balancerBcVaultVaultPool != address(0),
            "Balancer AB/AC/BC vault-vault pools missing"
        );
        require(balancerWethcVaultVaultPool != address(0), "Balancer vault-vault pool missing");
    }

    function _mintAndWrap() internal {
        IERC20MintBurn(ttA).mint(deployer, MINT_TTA);
        IERC20MintBurn(ttB).mint(deployer, MINT_TTB);
        IERC20MintBurn(ttC).mint(deployer, MINT_TTC);

        // Wrap enough ETH into WETH for LP minting
        uint256 haveWeth = IERC20(address(weth)).balanceOf(deployer);
        uint256 target = 10 * INITIAL_UNDERLYING_WETH;
        if (haveWeth < target) {
            weth.deposit{value: target - haveWeth}();
        }
    }

    function _approveMax(address token, address spender) internal {
        IERC20(token).approve(spender, 0);
        IERC20(token).approve(spender, type(uint256).max);
    }

    function _approve() internal {
        // Routers (for LP minting)
        _approveMax(address(weth), address(uniswapV2Router));
        _approveMax(ttA, address(uniswapV2Router));
        _approveMax(ttB, address(uniswapV2Router));
        _approveMax(ttC, address(uniswapV2Router));

        _approveMax(address(weth), address(aerodromeRouter));
        _approveMax(ttA, address(aerodromeRouter));
        _approveMax(ttB, address(aerodromeRouter));
        _approveMax(ttC, address(aerodromeRouter));

        // Balancer vault pulls vault shares
        _approveMax(uniAbVault, address(balancerV3Vault));
        _approveMax(uniAcVault, address(balancerV3Vault));
        _approveMax(uniBcVault, address(balancerV3Vault));
        _approveMax(aeroAbVault, address(balancerV3Vault));
        _approveMax(aeroAcVault, address(balancerV3Vault));
        _approveMax(aeroBcVault, address(balancerV3Vault));
        _approveMax(uniWethcVault, address(balancerV3Vault));
        _approveMax(aeroWethcVault, address(balancerV3Vault));

        // Vaults pull LP tokens (their asset)
        _approveMax(abPool, uniAbVault);
        _approveMax(acPool, uniAcVault);
        _approveMax(bcPool, uniBcVault);
        _approveMax(aeroAbPool, aeroAbVault);
        _approveMax(aeroAcPool, aeroAcVault);
        _approveMax(aeroBcPool, aeroBcVault);
        _approveMax(uniWethcPool, uniWethcVault);
        _approveMax(aeroWethcPool, aeroWethcVault);

        // Permit2 for Balancer Router (for vault share transfers during pool init)
        _approvePermit2(uniAbVault);
        _approvePermit2(uniAcVault);
        _approvePermit2(uniBcVault);
        _approvePermit2(aeroAbVault);
        _approvePermit2(aeroAcVault);
        _approvePermit2(aeroBcVault);
        _approvePermit2(uniWethcVault);
        _approvePermit2(aeroWethcVault);
    }

    function _approvePermit2(address token) internal {
        IERC20(token).approve(address(permit2), type(uint256).max);
        permit2.approve(address(token), address(balancerV3Router), type(uint160).max, type(uint48).max);
    }

    function _ensureUnderlyingForToken(address token, uint256 targetAmount) internal {
        if (token == address(weth)) {
            uint256 haveWeth = IERC20(address(weth)).balanceOf(deployer);
            if (haveWeth < targetAmount) {
                weth.deposit{value: targetAmount - haveWeth}();
            }
            return;
        }

        uint256 have = IERC20(token).balanceOf(deployer);
        if (have < targetAmount) {
            IERC20MintBurn(token).mint(deployer, targetAmount - have);
        }
    }

    function _mintUniV2LPForPool(address pool) internal {
        address token0 = IUniswapV2Pair(pool).token0();
        address token1 = IUniswapV2Pair(pool).token1();

        uint256 amt0 = token0 == address(weth) ? INITIAL_UNDERLYING_WETH : INITIAL_UNDERLYING_TOKEN;
        uint256 amt1 = token1 == address(weth) ? INITIAL_UNDERLYING_WETH : INITIAL_UNDERLYING_TOKEN;

        _ensureUnderlyingForToken(token0, amt0);
        _ensureUnderlyingForToken(token1, amt1);

        uint256 deadline = block.timestamp + 1 hours;
        uniswapV2Router.addLiquidity(token0, token1, amt0, amt1, 0, 0, deployer, deadline);
    }

    function _mintAeroLPForPool(address pool) internal {
        address token0 = IPool(pool).token0();
        address token1 = IPool(pool).token1();

        uint256 amt0 = token0 == address(weth) ? INITIAL_UNDERLYING_WETH : INITIAL_UNDERLYING_TOKEN;
        uint256 amt1 = token1 == address(weth) ? INITIAL_UNDERLYING_WETH : INITIAL_UNDERLYING_TOKEN;

        _ensureUnderlyingForToken(token0, amt0);
        _ensureUnderlyingForToken(token1, amt1);

        (uint256 amount0, uint256 amount1) = _aeroPoolDepositAmounts(pool, amt0, amt1);

        IERC20(token0).transfer(pool, amount0);
        IERC20(token1).transfer(pool, amount1);
        IPool(pool).mint(deployer);
    }

    function _aeroPoolDepositAmounts(address pool, uint256 amount0, uint256 amount1)
        internal
        view
        returns (uint256 adjustedAmount0, uint256 adjustedAmount1)
    {
        adjustedAmount0 = amount0;
        adjustedAmount1 = amount1;

        (uint256 reserve0, uint256 reserve1,) = IPool(pool).getReserves();
        if (reserve0 == 0 || reserve1 == 0 || adjustedAmount0 == 0 || adjustedAmount1 == 0) {
            return (adjustedAmount0, adjustedAmount1);
        }

        uint256 optimalAmount1 = (adjustedAmount0 * reserve1) / reserve0;
        if (optimalAmount1 <= adjustedAmount1) {
            adjustedAmount1 = optimalAmount1;
            return (adjustedAmount0, adjustedAmount1);
        }

        adjustedAmount0 = (adjustedAmount1 * reserve0) / reserve1;
        return (adjustedAmount0, adjustedAmount1);
    }

    function _depositVaultAssets(address vault, address asset, uint256 desiredAssets) internal returns (uint256 assetsDeposited, uint256 sharesMinted) {
        uint256 bal = IERC20(asset).balanceOf(deployer);
        assetsDeposited = bal < desiredAssets ? bal : desiredAssets;
        require(assetsDeposited > 0, "No vault assets to deposit");
        sharesMinted = IERC4626(vault).deposit(assetsDeposited, deployer);
    }

    function _ensureSharesUni(address vault, address pool, uint256 requiredShares) internal {
        uint256 have = IERC20(vault).balanceOf(deployer);
        if (have >= requiredShares) return;

        uint256 missing = requiredShares - have;
        uint256 neededAssets = IERC4626(vault).previewMint(missing);
        neededAssets = neededAssets + 1;

        // Ensure enough LP (vault asset) exists
        for (uint256 i = 0; i < 5; i++) {
            if (IERC20(pool).balanceOf(deployer) >= neededAssets) break;
            _mintUniV2LPForPool(pool);
        }

        _depositVaultAssets(vault, pool, neededAssets);
    }

    function _ensureSharesAero(address vault, address pool, uint256 requiredShares) internal {
        uint256 have = IERC20(vault).balanceOf(deployer);
        if (have >= requiredShares) return;

        uint256 missing = requiredShares - have;
        uint256 neededAssets = IERC4626(vault).previewMint(missing);
        neededAssets = neededAssets + 1;

        for (uint256 i = 0; i < 5; i++) {
            if (IERC20(pool).balanceOf(deployer) >= neededAssets) break;
            _mintAeroLPForPool(pool);
        }

        _depositVaultAssets(vault, pool, neededAssets);
    }

    function _seedBalancerVaultVaultPool(address balancerPool, address leftVault, address rightVault) internal {
        IERC20[] memory tokens = new IERC20[](2);
        tokens[0] = IERC20(leftVault);
        tokens[1] = IERC20(rightVault);

        // Sort tokens to match pool's internal ordering
        tokens = InputHelpers.sortTokens(tokens);

        // Both amounts are the same (INITIAL_VAULT_SHARES), so no need to swap
        uint256[] memory exactAmountsIn = new uint256[](2);
        exactAmountsIn[0] = INITIAL_VAULT_SHARES;
        exactAmountsIn[1] = INITIAL_VAULT_SHARES;

        // First initialize the pool (this also adds initial liquidity)
        balancerV3Router.initialize(balancerPool, tokens, exactAmountsIn, 0, false, bytes(""));
    }

    function _seedAllVaultVaultPools() internal {
        // Ensure equal shares for each paired vault set
        _ensureSharesUni(uniAbVault, abPool, INITIAL_VAULT_SHARES);
        _ensureSharesAero(aeroAbVault, aeroAbPool, INITIAL_VAULT_SHARES);
        _seedBalancerVaultVaultPool(balancerAbVaultVaultPool, aeroAbVault, uniAbVault);

        _ensureSharesUni(uniAcVault, acPool, INITIAL_VAULT_SHARES);
        _ensureSharesAero(aeroAcVault, aeroAcPool, INITIAL_VAULT_SHARES);
        _seedBalancerVaultVaultPool(balancerAcVaultVaultPool, aeroAcVault, uniAcVault);

        _ensureSharesUni(uniBcVault, bcPool, INITIAL_VAULT_SHARES);
        _ensureSharesAero(aeroBcVault, aeroBcPool, INITIAL_VAULT_SHARES);
        _seedBalancerVaultVaultPool(balancerBcVaultVaultPool, aeroBcVault, uniBcVault);

        _ensureSharesUni(uniWethcVault, uniWethcPool, INITIAL_VAULT_SHARES);
        _ensureSharesAero(aeroWethcVault, aeroWethcPool, INITIAL_VAULT_SHARES);
        _seedBalancerVaultVaultPool(balancerWethcVaultVaultPool, aeroWethcVault, uniWethcVault);
    }

    function _exportJson() internal {
        string memory json;
        json = vm.serializeAddress("", "balancerAbVaultVaultPool", balancerAbVaultVaultPool);
        json = vm.serializeAddress("", "balancerAcVaultVaultPool", balancerAcVaultVaultPool);
        json = vm.serializeAddress("", "balancerBcVaultVaultPool", balancerBcVaultVaultPool);
        json = vm.serializeAddress("", "balancerWethcVaultVaultPool", balancerWethcVaultVaultPool);
        json = vm.serializeUint("", "initialVaultShares", INITIAL_VAULT_SHARES);
        _writeJson(json, "23_weth_ttc_vault_vault_pool_liquidity.json");
    }

    function _logResults() internal view {
        _logAddress("Balancer V3 AB Vault-Vault Pool:", balancerAbVaultVaultPool);
        _logAddress("Balancer V3 AC Vault-Vault Pool:", balancerAcVaultVaultPool);
        _logAddress("Balancer V3 BC Vault-Vault Pool:", balancerBcVaultVaultPool);
        _logAddress("Balancer V3 WETH/TTC Vault-Vault Pool:", balancerWethcVaultVaultPool);
        _logComplete("Stage 23");
    }
}
