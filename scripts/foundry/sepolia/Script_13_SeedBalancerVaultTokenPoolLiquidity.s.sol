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
/*                                 Balancer V3                                */
/* -------------------------------------------------------------------------- */

import {IVault as IBalancerV3Vault} from "@crane/contracts/interfaces/protocols/dexes/balancer/v3/IVault.sol";

/// @title Script_13_SeedBalancerVaultTokenPoolLiquidity
/// @notice Seeds liquidity into Balancer vault-token pools
/// @dev Note: anvil_sepolia only has stages 01-09. This script adapts to use available deployments.
/// @dev Run:
///      forge script scripts/foundry/anvil_sepolia/Script_13_SeedBalancerVaultTokenPoolLiquidity.s.sol \
///        --rpc-url http://127.0.0.1:8545 --broadcast --unlocked --sender 0xf39Fd6e51aad88F6F4ce6aB8827279cffFb92266 -vvv
contract Script_13_SeedBalancerVaultTokenPoolLiquidity is DeploymentBase {
    /* ---------------------------------------------------------------------- */
    /*                                 Config                                 */
    /* ---------------------------------------------------------------------- */

    uint256 internal constant MINT_TEST_TOKENS = 1_000_000e18;

    // Amounts used to initialize each Balancer pool.
    uint256 internal constant INITIAL_UNDERLYING = 10_000e18;
    uint256 internal constant INITIAL_VAULT_SHARES = 10_000e18;

    // How many LP tokens (vault assets) to deposit into each vault to mint shares.
    uint256 internal constant VAULT_ASSET_DEPOSIT = 30_000e18;

    // Liquidity model for minting LP tokens
    uint256 internal constant LP_MINT_LIQUIDITY = 100_000e18;
    uint256 internal constant UNBALANCED_RATIO_B = 10_000e18;
    uint256 internal constant UNBALANCED_RATIO_C = 1_000e18;

    /* ---------------------------------------------------------------------- */
    /*                                  Inputs                                */
    /* ---------------------------------------------------------------------- */

    address private ttA;
    address private ttB;
    address private ttC;

    // Underlying DEX pools (these are the ERC4626 "asset" for each vault)
    address private abPool;
    address private acPool;
    address private bcPool;

    address private aeroAbPool;
    address private aeroAcPool;
    address private aeroBcPool;

    // Vaults (ERC4626 shares)
    address private abVault;
    address private acVault;
    address private bcVault;

    address private aeroAbVault;
    address private aeroAcVault;
    address private aeroBcVault;

    // Balancer vault-token pools would be deployed here (Stage 12 in anvil_base_main)
    // For anvil_sepolia, we note that these pools don't exist yet

    function run() external {
        _setup();
        _loadPreviousDeployments();

        _logHeader("Stage 13: Seed Balancer Vault-Token Pool Liquidity");

        vm.startBroadcast();
        _mintTestTokens();
        _approveRoutersVaultAndVaultShares();
        _mintVaultShares();
        // _seedBalancerVaultTokenPools(); // No Stage 12 pools in anvil_sepolia
        vm.stopBroadcast();

        _exportJson();
        _logResults();
    }

    function _loadPreviousDeployments() internal {
        ttA = _readAddress("07_test_tokens.json", "testTokenA");
        ttB = _readAddress("07_test_tokens.json", "testTokenB");
        ttC = _readAddress("07_test_tokens.json", "testTokenC");

        abPool = _readAddress("08_pools.json", "abPool");
        acPool = _readAddress("08_pools.json", "acPool");
        bcPool = _readAddress("08_pools.json", "bcPool");

        aeroAbPool = _readAddress("08_pools.json", "aeroAbPool");
        aeroAcPool = _readAddress("08_pools.json", "aeroAcPool");
        aeroBcPool = _readAddress("08_pools.json", "aeroBcPool");

        abVault = _readAddress("09_strategy_vaults.json", "abVault");
        acVault = _readAddress("09_strategy_vaults.json", "acVault");
        bcVault = _readAddress("09_strategy_vaults.json", "bcVault");

        // Try to read aerodrome vaults (may not exist in all configurations)
        (aeroAbVault, ) = _readAddressSafe("09_strategy_vaults.json", "aeroAbVault");
        (aeroAcVault, ) = _readAddressSafe("09_strategy_vaults.json", "aeroAcVault");
        (aeroBcVault, ) = _readAddressSafe("09_strategy_vaults.json", "aeroBcVault");

        // Load and set router addresses from previous deployments
        address uniRouter = _readAddress("05_uniswap_v2.json", "uniswapV2Router");
        address aeroRouter = _readAddress("06_aerodrome.json", "aerodromeRouter");
        
        require(uniRouter != address(0), "UniswapV2 router missing");
        require(aeroRouter != address(0), "Aerodrome router missing");
        
        _setOurUniswapV2(uniRouter, _readAddress("05_uniswap_v2.json", "uniswapV2Factory"));
        _setOurAerodrome(aeroRouter, _readAddress("06_aerodrome.json", "aerodromeFactory"));

        require(ttA != address(0) && ttB != address(0) && ttC != address(0), "Test tokens missing");
        require(abPool != address(0) && acPool != address(0) && bcPool != address(0), "UniV2 pools missing");
        require(aeroAbPool != address(0) && aeroAcPool != address(0) && aeroBcPool != address(0), "Aerodrome pools missing");
        require(abVault != address(0) && acVault != address(0) && bcVault != address(0), "UniV2 vaults missing");
    }

    function _mintTestTokens() internal {
        IERC20MintBurn(ttA).mint(deployer, MINT_TEST_TOKENS);
        IERC20MintBurn(ttB).mint(deployer, MINT_TEST_TOKENS);
        IERC20MintBurn(ttC).mint(deployer, MINT_TEST_TOKENS);
    }

    function _approveMax(address token, address spender) internal {
        IERC20(token).approve(spender, 0);
        IERC20(token).approve(spender, type(uint256).max);
    }

    function _approveRoutersVaultAndVaultShares() internal {
        // Routers
        _approveMax(ttA, address(uniswapV2Router));
        _approveMax(ttB, address(uniswapV2Router));
        _approveMax(ttC, address(uniswapV2Router));

        _approveMax(ttA, address(aerodromeRouter));
        _approveMax(ttB, address(aerodromeRouter));
        _approveMax(ttC, address(aerodromeRouter));

        // Balancer Vault pulls both underlying + vault shares
        _approveMax(ttA, address(balancerV3Vault));
        _approveMax(ttB, address(balancerV3Vault));
        _approveMax(ttC, address(balancerV3Vault));

        _approveMax(abVault, address(balancerV3Vault));
        _approveMax(acVault, address(balancerV3Vault));
        _approveMax(bcVault, address(balancerV3Vault));
        
        if (aeroAbVault != address(0)) {
            _approveMax(aeroAbVault, address(balancerV3Vault));
        }
        if (aeroAcVault != address(0)) {
            _approveMax(aeroAcVault, address(balancerV3Vault));
        }
        if (aeroBcVault != address(0)) {
            _approveMax(aeroBcVault, address(balancerV3Vault));
        }

        // Vaults pull LP tokens (their asset)
        _approveMax(abPool, abVault);
        _approveMax(acPool, acVault);
        _approveMax(bcPool, bcVault);

        _approveMax(aeroAbPool, aeroAbVault);
        _approveMax(aeroAcPool, aeroAcVault);
        _approveMax(aeroBcPool, aeroBcVault);
    }

    function _mintUniV2LP(address tokenX, address tokenY, uint256 amountX, uint256 amountY) internal {
        uint256 deadline = block.timestamp + 1 hours;
        uniswapV2Router.addLiquidity(tokenX, tokenY, amountX, amountY, 0, 0, deployer, deadline);
    }

    function _mintAeroLP(address tokenX, address tokenY, uint256 amountX, uint256 amountY) internal {
        uint256 deadline = block.timestamp + 1 hours;
        // volatile (stable=false)
        aerodromeRouter.addLiquidity(tokenX, tokenY, false, amountX, amountY, 0, 0, deployer, deadline);
    }

    function _depositVaultAssets(address vault, address asset, uint256 desiredAssets) internal returns (uint256 assetsDeposited, uint256 sharesMinted) {
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
        uint256 neededAssets = IERC4626(vault).previewMint(missingShares);
        // Round up to avoid preview/mint rounding edge cases.
        neededAssets = neededAssets + 1;

        // Ensure we have enough LP (vault asset) to deposit.
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
        if (vault == address(0)) return;
        
        uint256 haveShares = IERC20(vault).balanceOf(deployer);
        if (haveShares >= requiredShares) return;

        uint256 missingShares = requiredShares - haveShares;
        uint256 neededAssets = IERC4626(vault).previewMint(missingShares);
        neededAssets = neededAssets + 1;

        for (uint256 i = 0; i < 10; i++) {
            if (IERC20(pool).balanceOf(deployer) >= neededAssets) break;
            _mintAeroLP(tokenX, tokenY, mintAmountX, mintAmountY);
        }

        _depositVaultAssets(vault, pool, neededAssets);
    }

    function _mintVaultShares() internal {
        uint256 requiredSharesPerVault = 2 * INITIAL_VAULT_SHARES;

        // Mint UniV2 LPs and deposit into vaults until we have enough shares.
        _ensureVaultSharesUni(abVault, abPool, ttA, ttB, LP_MINT_LIQUIDITY, LP_MINT_LIQUIDITY, requiredSharesPerVault);
        _ensureVaultSharesUni(acVault, acPool, ttA, ttC, LP_MINT_LIQUIDITY, UNBALANCED_RATIO_B, requiredSharesPerVault);
        _ensureVaultSharesUni(bcVault, bcPool, ttB, ttC, LP_MINT_LIQUIDITY, UNBALANCED_RATIO_C, requiredSharesPerVault);

        // Mint Aerodrome LPs and deposit into vaults until we have enough shares.
        _ensureVaultSharesAero(
            aeroAbVault, aeroAbPool, ttA, ttB, LP_MINT_LIQUIDITY, LP_MINT_LIQUIDITY, requiredSharesPerVault
        );
        _ensureVaultSharesAero(aeroAcVault, aeroAcPool, ttA, ttC, LP_MINT_LIQUIDITY, UNBALANCED_RATIO_B, requiredSharesPerVault);
        _ensureVaultSharesAero(aeroBcVault, aeroBcPool, ttB, ttC, LP_MINT_LIQUIDITY, UNBALANCED_RATIO_C, requiredSharesPerVault);

        require(IERC20(abVault).balanceOf(deployer) >= requiredSharesPerVault, "Insufficient abVault shares");
        require(IERC20(acVault).balanceOf(deployer) >= requiredSharesPerVault, "Insufficient acVault shares");
        require(IERC20(bcVault).balanceOf(deployer) >= requiredSharesPerVault, "Insufficient bcVault shares");
    }

    function _exportJson() internal {
        string memory json;
        json = vm.serializeUint("", "mintTestTokens", MINT_TEST_TOKENS);
        json = vm.serializeUint("", "initialUnderlying", INITIAL_UNDERLYING);
        json = vm.serializeUint("", "initialVaultShares", INITIAL_VAULT_SHARES);
        json = vm.serializeUint("", "vaultAssetDeposit", VAULT_ASSET_DEPOSIT);
        _writeJson(json, "13_balancer_vault_token_pool_liquidity.json");
    }

    function _logResults() internal view {
        _logAddress("Test Token A:", ttA);
        _logAddress("Test Token B:", ttB);
        _logAddress("Test Token C:", ttC);
        
        _logAddress("UniV2 AB Pool:", abPool);
        _logAddress("UniV2 AC Pool:", acPool);
        _logAddress("UniV2 BC Pool:", bcPool);
        
        _logAddress("Aerodrome AB Pool:", aeroAbPool);
        _logAddress("Aerodrome AC Pool:", aeroAcPool);
        _logAddress("Aerodrome BC Pool:", aeroBcPool);
        
        _logAddress("UniV2 AB Vault:", abVault);
        _logAddress("UniV2 AC Vault:", acVault);
        _logAddress("UniV2 BC Vault:", bcVault);
        
        _logAddress("Aerodrome AB Vault:", aeroAbVault);
        _logAddress("Aerodrome AC Vault:", aeroAcVault);
        _logAddress("Aerodrome BC Vault:", aeroBcVault);

        _logComplete("Stage 13");
    }
}
