// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.0;

import {DeploymentBase} from "./DeploymentBase.sol";

/* -------------------------------------------------------------------------- */
/*                                OpenZeppelin                                */
/* -------------------------------------------------------------------------- */

import {IERC20} from "@crane/contracts/interfaces/IERC20.sol";

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

/// @title Script_21_SeedWethTtcBalancerVaultTokenPoolLiquidity
/// @notice Initializes Balancer vault-token pools for the WETH/TTC Standard Exchange vaults with small liquidity.
contract Script_21_SeedWethTtcBalancerVaultTokenPoolLiquidity is DeploymentBase {
    /* ---------------------------------------------------------------------- */
    /*                                 Config                                 */
    /* ---------------------------------------------------------------------- */

    uint256 internal constant MINT_TTC = 2_000_000e18;

    uint256 internal constant INITIAL_UNDERLYING_WETH = 10e18;
    uint256 internal constant INITIAL_UNDERLYING_TTC = 10_000e18;
    uint256 internal constant INITIAL_VAULT_SHARES = 1e18;

    /* ---------------------------------------------------------------------- */
    /*                                  Inputs                                */
    /* ---------------------------------------------------------------------- */

    address private ttC;

    // Underlying DEX pools (ERC4626 asset)
    address private uniWethcPool;
    address private aeroWethcPool;

    // Vaults (ERC4626 shares)
    address private uniWethcVault;
    address private aeroWethcVault;

    // Balancer vault-token pools (Stage 20)
    address private balUniWethcWithWeth;
    address private balUniWethcWithC;
    address private balAeroWethcWithWeth;
    address private balAeroWethcWithC;

    function run() external {
        _setup();
        _loadPreviousDeployments();

        _logHeader("Stage 21: Seed WETH/TTC Balancer Vault-Token Pool Liquidity");

        vm.startBroadcast();
        _mintAndWrap();
        _approve();
        _mintVaultShares();
        _seedBalancerVaultTokenPools();
        vm.stopBroadcast();

        _exportJson();
        _logResults();
    }

    function _loadPreviousDeployments() internal {
        ttC = _readAddress("05_test_tokens.json", "testTokenC");
        require(ttC != address(0), "Test Token C not found");

        uniWethcPool = _readAddress("17_weth_ttc_pools.json", "uniWethcPool");
        aeroWethcPool = _readAddress("17_weth_ttc_pools.json", "aeroWethcPool");

        uniWethcVault = _readAddress("18_weth_ttc_vaults.json", "uniWethcVault");
        aeroWethcVault = _readAddress("18_weth_ttc_vaults.json", "aeroWethcVault");

        balUniWethcWithWeth = _readAddress("20_weth_ttc_balancer_vault_token_pools.json", "balUniWethcWithWeth");
        balUniWethcWithC = _readAddress("20_weth_ttc_balancer_vault_token_pools.json", "balUniWethcWithC");
        balAeroWethcWithWeth = _readAddress("20_weth_ttc_balancer_vault_token_pools.json", "balAeroWethcWithWeth");
        balAeroWethcWithC = _readAddress("20_weth_ttc_balancer_vault_token_pools.json", "balAeroWethcWithC");

        require(uniWethcPool != address(0) && aeroWethcPool != address(0), "WETH/TTC pools missing");
        require(uniWethcVault != address(0) && aeroWethcVault != address(0), "WETH/TTC vaults missing");
        require(
            balUniWethcWithWeth != address(0) && balUniWethcWithC != address(0) && balAeroWethcWithWeth != address(0)
                && balAeroWethcWithC != address(0),
            "Balancer vault-token pools missing"
        );
    }

    function _mintAndWrap() internal {
        IERC20MintBurn(ttC).mint(deployer, MINT_TTC);

        // Wrap enough ETH into WETH for repeated LP mints + pool inits.
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
        _approveMax(ttC, address(uniswapV2Router));

        _approveMax(address(weth), address(aerodromeRouter));
        _approveMax(ttC, address(aerodromeRouter));

        // Vault pulls underlying + vault shares
        _approveMax(address(weth), address(balancerV3Vault));
        _approveMax(ttC, address(balancerV3Vault));
        _approveMax(uniWethcVault, address(balancerV3Vault));
        _approveMax(aeroWethcVault, address(balancerV3Vault));

        // Vaults pull LP tokens (their asset)
        _approveMax(uniWethcPool, uniWethcVault);
        _approveMax(aeroWethcPool, aeroWethcVault);

        // Permit2 for Balancer Router
        _approvePermit2(address(weth));
        _approvePermit2(ttC);
        _approvePermit2(uniWethcVault);
        _approvePermit2(aeroWethcVault);
    }

    function _approvePermit2(address token) internal {
        IERC20(token).approve(address(permit2), type(uint256).max);
        permit2.approve(address(token), address(balancerV3Router), type(uint160).max, type(uint48).max);
    }

    function _mintUniV2LP(uint256 wethAmt, uint256 ttcAmt) internal {
        uint256 deadline = block.timestamp + 1 hours;
        uniswapV2Router.addLiquidity(address(weth), ttC, wethAmt, ttcAmt, 0, 0, deployer, deadline);
    }

    function _mintAeroLP(uint256 wethAmt, uint256 ttcAmt) internal {
        uint256 deadline = block.timestamp + 1 hours;
        aerodromeRouter.addLiquidity(address(weth), ttC, false, wethAmt, ttcAmt, 0, 0, deployer, deadline);
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

        // Ensure enough LP (vault asset) exists.
        for (uint256 i = 0; i < 5; i++) {
            if (IERC20(pool).balanceOf(deployer) >= neededAssets) break;
            _mintUniV2LP(INITIAL_UNDERLYING_WETH, INITIAL_UNDERLYING_TTC);
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
            _mintAeroLP(INITIAL_UNDERLYING_WETH, INITIAL_UNDERLYING_TTC);
        }

        _depositVaultAssets(vault, pool, neededAssets);
    }

    function _mintVaultShares() internal {
        // We need shares for both Balancer pools per vault.
        uint256 required = 2 * INITIAL_VAULT_SHARES;

        _ensureSharesUni(uniWethcVault, uniWethcPool, required);
        _ensureSharesAero(aeroWethcVault, aeroWethcPool, required);

        require(IERC20(uniWethcVault).balanceOf(deployer) >= required, "Insufficient UniV2 WETH/TTC shares");
        require(IERC20(aeroWethcVault).balanceOf(deployer) >= required, "Insufficient Aerodrome WETH/TTC shares");
    }

    function _seedBalancerPool(address pool, address tokenX, uint256 amountX, address tokenY, uint256 amountY) internal {
        IERC20[] memory tokens = new IERC20[](2);
        tokens[0] = IERC20(tokenX);
        tokens[1] = IERC20(tokenY);

        // Sort tokens to match pool's internal ordering
        tokens = InputHelpers.sortTokens(tokens);

        // Map amounts to sorted token order
        uint256[] memory exactAmountsIn = new uint256[](2);
        if (tokens[0] == IERC20(tokenX)) {
            exactAmountsIn[0] = amountX;
            exactAmountsIn[1] = amountY;
        } else {
            exactAmountsIn[0] = amountY;
            exactAmountsIn[1] = amountX;
        }

        // First initialize the pool (this also adds initial liquidity)
        balancerV3Router.initialize(pool, tokens, exactAmountsIn, 0, false, bytes(""));
    }

    function _seedBalancerVaultTokenPools() internal {
        // Pools with underlying WETH get small WETH deposits.
        _seedBalancerPool(balUniWethcWithWeth, address(weth), INITIAL_UNDERLYING_WETH, uniWethcVault, INITIAL_VAULT_SHARES);
        _seedBalancerPool(balAeroWethcWithWeth, address(weth), INITIAL_UNDERLYING_WETH, aeroWethcVault, INITIAL_VAULT_SHARES);

        // Pools with underlying TTC can use larger TTC deposits.
        _seedBalancerPool(balUniWethcWithC, ttC, INITIAL_UNDERLYING_TTC, uniWethcVault, INITIAL_VAULT_SHARES);
        _seedBalancerPool(balAeroWethcWithC, ttC, INITIAL_UNDERLYING_TTC, aeroWethcVault, INITIAL_VAULT_SHARES);
    }

    function _exportJson() internal {
        string memory json;
        json = vm.serializeUint("", "initialUnderlyingWeth", INITIAL_UNDERLYING_WETH);
        json = vm.serializeUint("", "initialUnderlyingTtc", INITIAL_UNDERLYING_TTC);
        json = vm.serializeUint("", "initialVaultShares", INITIAL_VAULT_SHARES);
        _writeJson(json, "21_weth_ttc_balancer_vault_token_pool_liquidity.json");
    }

    function _logResults() internal view {
        _logAddress("Balancer Uni WETH/TTC vault-token pool (WETH):", balUniWethcWithWeth);
        _logAddress("Balancer Uni WETH/TTC vault-token pool (TTC):", balUniWethcWithC);
        _logAddress("Balancer Aero WETH/TTC vault-token pool (WETH):", balAeroWethcWithWeth);
        _logAddress("Balancer Aero WETH/TTC vault-token pool (TTC):", balAeroWethcWithC);
        _logComplete("Stage 21");
    }
}
