// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.0;

import {DeploymentBase} from "./DeploymentBase.sol";

import {IERC20} from "@crane/contracts/interfaces/IERC20.sol";
import {IERC4626} from "@crane/contracts/interfaces/IERC4626.sol";
import {IPool} from "@crane/contracts/interfaces/protocols/dexes/aerodrome/IPool.sol";
import {InputHelpers} from "@crane/contracts/external/balancer/v3/solidity-utils/contracts/helpers/InputHelpers.sol";

import {BridgeTokenPlanning} from "../shared/BridgeTokenPlanning.sol";

contract Script_13_SeedBalancerVaultTokenPoolLiquidity is DeploymentBase {
    uint256 internal constant INITIAL_UNDERLYING = 10_000e18;
    uint256 internal constant INITIAL_VAULT_SHARES = 10_000e18;
    uint256 internal constant VAULT_ASSET_DEPOSIT = 30_000e18;
    uint256 internal constant LP_MINT_LIQUIDITY = 100_000e18;
    uint256 internal constant UNBALANCED_RATIO_B = 10_000e18;
    uint256 internal constant UNBALANCED_RATIO_C = 1_000e18;

    address private ttA;
    address private ttB;
    address private ttC;

    address private abPool;
    address private acPool;
    address private bcPool;

    address private aeroAbPool;
    address private aeroAcPool;
    address private aeroBcPool;

    address private abVault;
    address private acVault;
    address private bcVault;

    address private aeroAbVault;
    address private aeroAcVault;
    address private aeroBcVault;

    address private balUniAbWithA;
    address private balUniAbWithB;
    address private balUniAcWithA;
    address private balUniAcWithC;
    address private balUniBcWithB;
    address private balUniBcWithC;

    address private balAeroAbWithA;
    address private balAeroAbWithB;
    address private balAeroAcWithA;
    address private balAeroAcWithC;
    address private balAeroBcWithB;
    address private balAeroBcWithC;

    function run() external {
        _setup();
        _loadPreviousDeployments();

        _logHeader("Stage 13: Seed Balancer Vault-Token Pool Liquidity");

        vm.startBroadcast();
        _assertBridgedBalances();
        _approveRoutersVaultAndVaultShares();
        _mintVaultShares();
        _seedBalancerVaultTokenPools();
        vm.stopBroadcast();

        _exportJson();
        _logResults();
    }

    function _loadPreviousDeployments() internal {
        ttA = _readAddress("05_test_tokens.json", "testTokenA");
        ttB = _readAddress("05_test_tokens.json", "testTokenB");
        ttC = _readAddress("05_test_tokens.json", "testTokenC");

        abPool = _readAddress("06_pools.json", "abPool");
        acPool = _readAddress("06_pools.json", "acPool");
        bcPool = _readAddress("06_pools.json", "bcPool");

        aeroAbPool = _readAddress("06_pools.json", "aeroAbPool");
        aeroAcPool = _readAddress("06_pools.json", "aeroAcPool");
        aeroBcPool = _readAddress("06_pools.json", "aeroBcPool");

        abVault = _readAddress("07_strategy_vaults.json", "abVault");
        acVault = _readAddress("07_strategy_vaults.json", "acVault");
        bcVault = _readAddress("07_strategy_vaults.json", "bcVault");

        aeroAbVault = _readAddress("08_aerodrome_strategy_vaults.json", "aeroAbVault");
        aeroAcVault = _readAddress("08_aerodrome_strategy_vaults.json", "aeroAcVault");
        aeroBcVault = _readAddress("08_aerodrome_strategy_vaults.json", "aeroBcVault");

        balUniAbWithA = _readAddress("12_balancer_const_prod_vault_token_pools.json", "balUniAbWithA");
        balUniAbWithB = _readAddress("12_balancer_const_prod_vault_token_pools.json", "balUniAbWithB");
        balUniAcWithA = _readAddress("12_balancer_const_prod_vault_token_pools.json", "balUniAcWithA");
        balUniAcWithC = _readAddress("12_balancer_const_prod_vault_token_pools.json", "balUniAcWithC");
        balUniBcWithB = _readAddress("12_balancer_const_prod_vault_token_pools.json", "balUniBcWithB");
        balUniBcWithC = _readAddress("12_balancer_const_prod_vault_token_pools.json", "balUniBcWithC");

        balAeroAbWithA = _readAddress("12_balancer_const_prod_vault_token_pools.json", "balAeroAbWithA");
        balAeroAbWithB = _readAddress("12_balancer_const_prod_vault_token_pools.json", "balAeroAbWithB");
        balAeroAcWithA = _readAddress("12_balancer_const_prod_vault_token_pools.json", "balAeroAcWithA");
        balAeroAcWithC = _readAddress("12_balancer_const_prod_vault_token_pools.json", "balAeroAcWithC");
        balAeroBcWithB = _readAddress("12_balancer_const_prod_vault_token_pools.json", "balAeroBcWithB");
        balAeroBcWithC = _readAddress("12_balancer_const_prod_vault_token_pools.json", "balAeroBcWithC");

        require(ttA != address(0) && ttB != address(0) && ttC != address(0), "Test tokens missing");
        require(abPool != address(0) && acPool != address(0) && bcPool != address(0), "UniV2 pools missing");
        require(aeroAbPool != address(0) && aeroAcPool != address(0) && aeroBcPool != address(0), "Aerodrome pools missing");
        require(abVault != address(0) && acVault != address(0) && bcVault != address(0), "UniV2 vaults missing");
        require(aeroAbVault != address(0) && aeroAcVault != address(0) && aeroBcVault != address(0), "Aerodrome vaults missing");
        require(
            balUniAbWithA != address(0) && balUniAbWithB != address(0) && balUniAcWithA != address(0) && balUniAcWithC != address(0)
                && balUniBcWithB != address(0) && balUniBcWithC != address(0) && balAeroAbWithA != address(0)
                && balAeroAbWithB != address(0) && balAeroAcWithA != address(0) && balAeroAcWithC != address(0)
                && balAeroBcWithB != address(0) && balAeroBcWithC != address(0),
            "Stage 12 pools missing"
        );
    }

    function _assertBridgedBalances() internal view {
        require(
            IERC20(ttA).balanceOf(deployer) >= BridgeTokenPlanning.bridgeAmountTTA() - (3 * INITIAL_LIQUIDITY),
            "Insufficient bridged TTA for Stage 13"
        );
        require(
            IERC20(ttB).balanceOf(deployer) >= BridgeTokenPlanning.bridgeAmountTTB() - (3 * INITIAL_LIQUIDITY),
            "Insufficient bridged TTB for Stage 13"
        );
        require(
            IERC20(ttC).balanceOf(deployer) >= BridgeTokenPlanning.bridgeAmountTTC() - (UNBALANCED_RATIO_B + 2 * UNBALANCED_RATIO_C),
            "Insufficient bridged TTC for Stage 13"
        );
    }

    function _approveMax(address token, address spender) internal {
        IERC20(token).approve(spender, 0);
        IERC20(token).approve(spender, type(uint256).max);
    }

    function _approveRoutersVaultAndVaultShares() internal {
        _approveMax(ttA, address(uniswapV2Router));
        _approveMax(ttB, address(uniswapV2Router));
        _approveMax(ttC, address(uniswapV2Router));

        _approveMax(ttA, address(aerodromeRouter));
        _approveMax(ttB, address(aerodromeRouter));
        _approveMax(ttC, address(aerodromeRouter));

        _approveMax(ttA, address(balancerV3Vault));
        _approveMax(ttB, address(balancerV3Vault));
        _approveMax(ttC, address(balancerV3Vault));

        _approveMax(abVault, address(balancerV3Vault));
        _approveMax(acVault, address(balancerV3Vault));
        _approveMax(bcVault, address(balancerV3Vault));
        _approveMax(aeroAbVault, address(balancerV3Vault));
        _approveMax(aeroAcVault, address(balancerV3Vault));
        _approveMax(aeroBcVault, address(balancerV3Vault));

        _approveMax(abPool, abVault);
        _approveMax(acPool, acVault);
        _approveMax(bcPool, bcVault);

        _approveMax(aeroAbPool, aeroAbVault);
        _approveMax(aeroAcPool, aeroAcVault);
        _approveMax(aeroBcPool, aeroBcVault);

        _approvePermit2(ttA);
        _approvePermit2(ttB);
        _approvePermit2(ttC);
        _approvePermit2(abVault);
        _approvePermit2(acVault);
        _approvePermit2(bcVault);
        _approvePermit2(aeroAbVault);
        _approvePermit2(aeroAcVault);
        _approvePermit2(aeroBcVault);
    }

    function _approvePermit2(address token) internal {
        IERC20(token).approve(address(permit2), type(uint256).max);
        permit2.approve(address(token), address(balancerV3Router), type(uint160).max, type(uint48).max);
    }

    function _mintUniV2LP(address tokenX, address tokenY, uint256 amountX, uint256 amountY) internal {
        uint256 deadline = block.timestamp + 1 hours;
        uniswapV2Router.addLiquidity(tokenX, tokenY, amountX, amountY, 0, 0, deployer, deadline);
    }

    function _mintAeroLP(address tokenX, address tokenY, uint256 amountX, uint256 amountY) internal {
        address pool = aerodromePoolFactory.getPool(tokenX, tokenY, false);
        require(pool != address(0), "Aerodrome pool missing");

        (uint256 amount0, uint256 amount1) = _aeroPoolDepositAmounts(pool, tokenX, tokenY, amountX, amountY);
        address token0 = IPool(pool).token0();
        address token1 = IPool(pool).token1();

        IERC20(token0).transfer(pool, amount0);
        IERC20(token1).transfer(pool, amount1);
        IPool(pool).mint(deployer);
    }

    function _aeroPoolDepositAmounts(address pool, address tokenX, address tokenY, uint256 amountX, uint256 amountY)
        internal
        view
        returns (uint256 amount0, uint256 amount1)
    {
        IPool aeroPool = IPool(pool);
        address token0 = aeroPool.token0();
        address token1 = aeroPool.token1();

        if (token0 == tokenX && token1 == tokenY) {
            amount0 = amountX;
            amount1 = amountY;
        } else {
            require(token0 == tokenY && token1 == tokenX, "Aerodrome pool token mismatch");
            amount0 = amountY;
            amount1 = amountX;
        }

        (uint256 reserve0, uint256 reserve1,) = aeroPool.getReserves();
        if (reserve0 == 0 || reserve1 == 0 || amount0 == 0 || amount1 == 0) {
            return (amount0, amount1);
        }

        uint256 optimalAmount1 = (amount0 * reserve1) / reserve0;
        if (optimalAmount1 <= amount1) {
            amount1 = optimalAmount1;
            return (amount0, amount1);
        }

        amount0 = (amount1 * reserve0) / reserve1;
        return (amount0, amount1);
    }

    function _depositVaultAssets(address vault, address asset, uint256 desiredAssets)
        internal
        returns (uint256 assetsDeposited, uint256 sharesMinted)
    {
        uint256 bal = IERC20(asset).balanceOf(deployer);
        assetsDeposited = bal < desiredAssets ? bal : desiredAssets;
        require(assetsDeposited > 0, "No vault assets to deposit");
        sharesMinted = IERC4626(vault).deposit(assetsDeposited, deployer);
    }

    function _ensureVaultSharesUni(
        address vault,
        address pool,
        address tokenX,
        address tokenY,
        uint256 mintAmountX,
        uint256 mintAmountY,
        uint256 requiredShares
    ) internal {
        uint256 haveShares = IERC20(vault).balanceOf(deployer);
        if (haveShares >= requiredShares) return;

        uint256 missingShares = requiredShares - haveShares;
        uint256 neededAssets = IERC4626(vault).previewMint(missingShares) + 1;

        for (uint256 i = 0; i < 10; i++) {
            if (IERC20(pool).balanceOf(deployer) >= neededAssets) break;
            _mintUniV2LP(tokenX, tokenY, mintAmountX, mintAmountY);
        }

        _depositVaultAssets(vault, pool, neededAssets);
    }

    function _ensureVaultSharesAero(
        address vault,
        address pool,
        address tokenX,
        address tokenY,
        uint256 mintAmountX,
        uint256 mintAmountY,
        uint256 requiredShares
    ) internal {
        uint256 haveShares = IERC20(vault).balanceOf(deployer);
        if (haveShares >= requiredShares) return;

        uint256 missingShares = requiredShares - haveShares;
        uint256 neededAssets = IERC4626(vault).previewMint(missingShares) + 1;

        for (uint256 i = 0; i < 10; i++) {
            if (IERC20(pool).balanceOf(deployer) >= neededAssets) break;
            _mintAeroLP(tokenX, tokenY, mintAmountX, mintAmountY);
        }

        _depositVaultAssets(vault, pool, neededAssets);
    }

    function _mintVaultShares() internal {
        uint256 requiredSharesPerVault = 2 * INITIAL_VAULT_SHARES;

        _ensureVaultSharesUni(abVault, abPool, ttA, ttB, LP_MINT_LIQUIDITY, LP_MINT_LIQUIDITY, requiredSharesPerVault);
        _ensureVaultSharesUni(acVault, acPool, ttA, ttC, LP_MINT_LIQUIDITY, UNBALANCED_RATIO_B, requiredSharesPerVault);
        _ensureVaultSharesUni(bcVault, bcPool, ttB, ttC, LP_MINT_LIQUIDITY, UNBALANCED_RATIO_C, requiredSharesPerVault);

        _ensureVaultSharesAero(aeroAbVault, aeroAbPool, ttA, ttB, LP_MINT_LIQUIDITY, LP_MINT_LIQUIDITY, requiredSharesPerVault);
        _ensureVaultSharesAero(aeroAcVault, aeroAcPool, ttA, ttC, LP_MINT_LIQUIDITY, UNBALANCED_RATIO_B, requiredSharesPerVault);
        _ensureVaultSharesAero(aeroBcVault, aeroBcPool, ttB, ttC, LP_MINT_LIQUIDITY, UNBALANCED_RATIO_C, requiredSharesPerVault);

        require(IERC20(abVault).balanceOf(deployer) >= requiredSharesPerVault, "Insufficient abVault shares");
        require(IERC20(acVault).balanceOf(deployer) >= requiredSharesPerVault, "Insufficient acVault shares");
        require(IERC20(bcVault).balanceOf(deployer) >= requiredSharesPerVault, "Insufficient bcVault shares");
        require(IERC20(aeroAbVault).balanceOf(deployer) >= requiredSharesPerVault, "Insufficient aeroAbVault shares");
        require(IERC20(aeroAcVault).balanceOf(deployer) >= requiredSharesPerVault, "Insufficient aeroAcVault shares");
        require(IERC20(aeroBcVault).balanceOf(deployer) >= requiredSharesPerVault, "Insufficient aeroBcVault shares");
    }

    function _seedBalancerPool(address pool, address tokenX, uint256 amountX, address tokenY, uint256 amountY) internal {
        IERC20[] memory tokens = new IERC20[](2);
        tokens[0] = IERC20(tokenX);
        tokens[1] = IERC20(tokenY);
        tokens = InputHelpers.sortTokens(tokens);

        uint256[] memory exactAmountsIn = new uint256[](2);
        if (tokens[0] == IERC20(tokenX)) {
            exactAmountsIn[0] = amountX;
            exactAmountsIn[1] = amountY;
        } else {
            exactAmountsIn[0] = amountY;
            exactAmountsIn[1] = amountX;
        }

        balancerV3Router.initialize(pool, tokens, exactAmountsIn, 0, false, bytes(""));
    }

    function _seedBalancerVaultTokenPools() internal {
        _seedBalancerPool(balUniAbWithA, ttA, INITIAL_UNDERLYING, abVault, INITIAL_VAULT_SHARES);
        _seedBalancerPool(balUniAbWithB, ttB, INITIAL_UNDERLYING, abVault, INITIAL_VAULT_SHARES);
        _seedBalancerPool(balUniAcWithA, ttA, INITIAL_UNDERLYING, acVault, INITIAL_VAULT_SHARES);
        _seedBalancerPool(balUniAcWithC, ttC, INITIAL_UNDERLYING, acVault, INITIAL_VAULT_SHARES);
        _seedBalancerPool(balUniBcWithB, ttB, INITIAL_UNDERLYING, bcVault, INITIAL_VAULT_SHARES);
        _seedBalancerPool(balUniBcWithC, ttC, INITIAL_UNDERLYING, bcVault, INITIAL_VAULT_SHARES);

        _seedBalancerPool(balAeroAbWithA, ttA, INITIAL_UNDERLYING, aeroAbVault, INITIAL_VAULT_SHARES);
        _seedBalancerPool(balAeroAbWithB, ttB, INITIAL_UNDERLYING, aeroAbVault, INITIAL_VAULT_SHARES);
        _seedBalancerPool(balAeroAcWithA, ttA, INITIAL_UNDERLYING, aeroAcVault, INITIAL_VAULT_SHARES);
        _seedBalancerPool(balAeroAcWithC, ttC, INITIAL_UNDERLYING, aeroAcVault, INITIAL_VAULT_SHARES);
        _seedBalancerPool(balAeroBcWithB, ttB, INITIAL_UNDERLYING, aeroBcVault, INITIAL_VAULT_SHARES);
        _seedBalancerPool(balAeroBcWithC, ttC, INITIAL_UNDERLYING, aeroBcVault, INITIAL_VAULT_SHARES);
    }

    function _exportJson() internal {
        string memory json;
        json = vm.serializeUint("", "initialUnderlying", INITIAL_UNDERLYING);
        json = vm.serializeUint("", "initialVaultShares", INITIAL_VAULT_SHARES);
        json = vm.serializeUint("", "vaultAssetDeposit", VAULT_ASSET_DEPOSIT);
        _writeJson(json, "13_balancer_vault_token_pool_liquidity.json");
    }

    function _logResults() internal view {
        _logAddress("Balancer UniV2 AB vault + ttA:", balUniAbWithA);
        _logAddress("Balancer UniV2 AB vault + ttB:", balUniAbWithB);
        _logAddress("Balancer UniV2 AC vault + ttA:", balUniAcWithA);
        _logAddress("Balancer UniV2 AC vault + ttC:", balUniAcWithC);
        _logAddress("Balancer UniV2 BC vault + ttB:", balUniBcWithB);
        _logAddress("Balancer UniV2 BC vault + ttC:", balUniBcWithC);
        _logAddress("Balancer Aerodrome AB vault + ttA:", balAeroAbWithA);
        _logAddress("Balancer Aerodrome AB vault + ttB:", balAeroAbWithB);
        _logAddress("Balancer Aerodrome AC vault + ttA:", balAeroAcWithA);
        _logAddress("Balancer Aerodrome AC vault + ttC:", balAeroAcWithC);
        _logAddress("Balancer Aerodrome BC vault + ttB:", balAeroBcWithB);
        _logAddress("Balancer Aerodrome BC vault + ttC:", balAeroBcWithC);
        _logComplete("Stage 13");
    }
}