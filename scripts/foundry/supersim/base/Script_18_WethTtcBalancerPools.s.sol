// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.0;

import {DeploymentBase} from "../../anvil_base_main/DeploymentBase.sol";

import {IERC20} from "@crane/contracts/interfaces/IERC20.sol";
import {IERC20MintBurn} from "@crane/contracts/interfaces/IERC20MintBurn.sol";
import {IERC4626} from "@crane/contracts/interfaces/IERC4626.sol";
import {IPool as IAerodromePool} from "@crane/contracts/interfaces/protocols/dexes/aerodrome/IPool.sol";

import {InputHelpers} from "@crane/contracts/external/balancer/v3/solidity-utils/contracts/helpers/InputHelpers.sol";
import {TokenConfig, TokenType} from "@crane/contracts/interfaces/protocols/dexes/balancer/v3/VaultTypes.sol";
import {IRateProvider} from "@crane/contracts/interfaces/protocols/dexes/balancer/v3/IRateProvider.sol";

import {IStandardExchange} from "contracts/interfaces/IStandardExchange.sol";
import {IStandardExchangeRateProviderDFPkg} from
    "contracts/protocols/dexes/balancer/v3/rateProviders/StandardExchangeRateProviderDFPkg.sol";
import {IBalancerV3ConstantProductPoolStandardVaultPkg} from
    "contracts/protocols/dexes/balancer/v3/pools/constProd/BalancerV3ConstantProductPoolStandardVaultPkg.sol";

contract Script_18_WethTtcBalancerPools is DeploymentBase {
    uint256 internal constant MINT_TTC = 2_000_000e18;
    uint256 internal constant INITIAL_UNDERLYING_WETH = 10e18;
    uint256 internal constant INITIAL_UNDERLYING_TTC = 10_000e18;
    uint256 internal constant INITIAL_VAULT_SHARES = 1e18;

    IStandardExchangeRateProviderDFPkg private rateProviderPkg;
    IBalancerV3ConstantProductPoolStandardVaultPkg private balConstProdPkg;

    address private ttC;
    IAerodromePool private aeroWethcPool;
    address private aeroWethcVault;

    address private balancerWethcPool;
    address private aeroWethcRpWeth;
    address private aeroWethcRpC;
    address private balAeroWethcWithWeth;
    address private balAeroWethcWithC;

    function run() external {
        _setup();
        _loadPreviousDeployments();

        _logHeader("Base Stage 18: Aerodrome WETH/TTC Balancer Pools");

        vm.startBroadcast();
        _deployRateProviders();
        _deployPools();
        _mintAndWrap();
        _approve();
        _ensureAeroVaultShares(2 * INITIAL_VAULT_SHARES);
        _seedBalancerPools();
        vm.stopBroadcast();

        _exportJson();
        _logResults();
    }

    function _loadPreviousDeployments() internal {
        rateProviderPkg = IStandardExchangeRateProviderDFPkg(_readAddress("04_dex_packages.json", "rateProviderPkg"));
        balConstProdPkg = IBalancerV3ConstantProductPoolStandardVaultPkg(
            _readAddress("04_dex_packages.json", "balancerV3ConstantProductPoolStandardVaultPkg")
        );

        ttC = _readAddress("05_test_tokens.json", "testTokenC");
        aeroWethcPool = IAerodromePool(_readAddress("17_weth_ttc_pools.json", "aeroWethcPool"));
        aeroWethcVault = _readAddress("18_weth_ttc_vaults.json", "aeroWethcVault");

        require(address(rateProviderPkg) != address(0), "Rate provider pkg not found");
        require(address(balConstProdPkg) != address(0), "Balancer const-prod pkg not found");
        require(ttC != address(0), "Test Token C not found");
        require(address(aeroWethcPool) != address(0), "Aerodrome WETH/TTC pool not found");
        require(aeroWethcVault != address(0), "Aerodrome WETH/TTC vault not found");
    }

    function _standardTokenConfig(address token) internal pure returns (TokenConfig memory cfg) {
        cfg = TokenConfig({
            token: IERC20(token),
            tokenType: TokenType.STANDARD,
            rateProvider: IRateProvider(address(0)),
            paysYieldFees: false
        });
    }

    function _vaultTokenConfig(address vaultToken, address rateProvider) internal pure returns (TokenConfig memory cfg) {
        cfg = TokenConfig({
            token: IERC20(vaultToken),
            tokenType: TokenType.WITH_RATE,
            rateProvider: IRateProvider(rateProvider),
            paysYieldFees: false
        });
    }

    function _deployRateProviders() internal {
        aeroWethcRpWeth = address(rateProviderPkg.deployRateProvider(IStandardExchange(aeroWethcVault), IERC20(address(weth))));
        aeroWethcRpC = address(rateProviderPkg.deployRateProvider(IStandardExchange(aeroWethcVault), IERC20(ttC)));
    }

    function _deployTokenOnlyPool(address token0, address token1) internal returns (address pool) {
        TokenConfig[] memory cfg = new TokenConfig[](2);
        cfg[0] = _standardTokenConfig(token0);
        cfg[1] = _standardTokenConfig(token1);
        pool = balConstProdPkg.deployVault(cfg, address(0));
    }

    function _deployVaultTokenPool(address underlyingToken, address vaultToken, address vaultTokenRateProvider)
        internal
        returns (address pool)
    {
        TokenConfig[] memory cfg = new TokenConfig[](2);
        cfg[0] = _standardTokenConfig(underlyingToken);
        cfg[1] = _vaultTokenConfig(vaultToken, vaultTokenRateProvider);
        pool = balConstProdPkg.deployVault(cfg, address(0));
    }

    function _deployPools() internal {
        balancerWethcPool = _deployTokenOnlyPool(address(weth), ttC);
        balAeroWethcWithWeth = _deployVaultTokenPool(address(weth), aeroWethcVault, aeroWethcRpC);
        balAeroWethcWithC = _deployVaultTokenPool(ttC, aeroWethcVault, aeroWethcRpWeth);
    }

    function _mintAndWrap() internal {
        IERC20MintBurn(ttC).mint(deployer, MINT_TTC);

        uint256 haveWeth = IERC20(address(weth)).balanceOf(deployer);
        uint256 targetWeth = 10 * INITIAL_UNDERLYING_WETH;
        if (haveWeth < targetWeth) {
            weth.deposit{value: targetWeth - haveWeth}();
        }
    }

    function _approveMax(address token, address spender) internal {
        IERC20(token).approve(spender, 0);
        IERC20(token).approve(spender, type(uint256).max);
    }

    function _approvePermit2(address token) internal {
        IERC20(token).approve(address(permit2), type(uint256).max);
        permit2.approve(address(token), address(balancerV3Router), type(uint160).max, type(uint48).max);
    }

    function _approve() internal {
        _approveMax(address(weth), address(aerodromeRouter));
        _approveMax(ttC, address(aerodromeRouter));

        _approveMax(address(weth), address(balancerV3Vault));
        _approveMax(ttC, address(balancerV3Vault));
        _approveMax(address(aeroWethcPool), aeroWethcVault);
        _approveMax(aeroWethcVault, address(balancerV3Vault));

        _approvePermit2(address(weth));
        _approvePermit2(ttC);
        _approvePermit2(aeroWethcVault);
    }

    function _mintAeroLp(uint256 wethAmt, uint256 ttcAmt) internal {
        uint256 deadline = block.timestamp + 1 hours;
        aerodromeRouter.addLiquidity(address(weth), ttC, false, wethAmt, ttcAmt, 0, 0, deployer, deadline);
    }

    function _ensureAeroVaultShares(uint256 requiredShares) internal {
        uint256 have = IERC20(aeroWethcVault).balanceOf(deployer);
        if (have >= requiredShares) {
            return;
        }

        uint256 missing = requiredShares - have;
        uint256 neededAssets = IERC4626(aeroWethcVault).previewMint(missing) + 1;

        for (uint256 i = 0; i < 5; i++) {
            if (IERC20(address(aeroWethcPool)).balanceOf(deployer) >= neededAssets) {
                break;
            }
            _mintAeroLp(INITIAL_UNDERLYING_WETH, INITIAL_UNDERLYING_TTC);
        }

        IERC4626(aeroWethcVault).deposit(neededAssets, deployer);
        require(IERC20(aeroWethcVault).balanceOf(deployer) >= requiredShares, "Insufficient Aerodrome WETH/TTC shares");
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

    function _seedBalancerPools() internal {
        _seedBalancerPool(balancerWethcPool, address(weth), INITIAL_UNDERLYING_WETH, ttC, INITIAL_UNDERLYING_TTC);
        _seedBalancerPool(balAeroWethcWithWeth, address(weth), INITIAL_UNDERLYING_WETH, aeroWethcVault, INITIAL_VAULT_SHARES);
        _seedBalancerPool(balAeroWethcWithC, ttC, INITIAL_UNDERLYING_TTC, aeroWethcVault, INITIAL_VAULT_SHARES);
    }

    function _exportJson() internal {
        string memory json;
        json = vm.serializeAddress("", "rateProviderPkg", address(rateProviderPkg));
        json = vm.serializeAddress("", "balancerV3ConstantProductPoolStandardVaultPkg", address(balConstProdPkg));
        json = vm.serializeAddress("", "balancerWethcPool", balancerWethcPool);
        json = vm.serializeAddress("", "aeroWethcRpWeth", aeroWethcRpWeth);
        json = vm.serializeAddress("", "aeroWethcRpC", aeroWethcRpC);
        json = vm.serializeAddress("", "balAeroWethcWithWeth", balAeroWethcWithWeth);
        json = vm.serializeAddress("", "balAeroWethcWithC", balAeroWethcWithC);
        _writeJson(json, "20_weth_ttc_balancer_vault_token_pools.json");
    }

    function _logResults() internal view {
        _logAddress("Balancer WETH/TTC ConstProd Pool:", balancerWethcPool);
        _logAddress("Aerodrome WETH/TTC RateProvider (WETH):", aeroWethcRpWeth);
        _logAddress("Aerodrome WETH/TTC RateProvider (TTC):", aeroWethcRpC);
        _logAddress("Balancer Aerodrome WETH/TTC Vault + WETH Pool:", balAeroWethcWithWeth);
        _logAddress("Balancer Aerodrome WETH/TTC Vault + TTC Pool:", balAeroWethcWithC);
        _logComplete("Base Stage 18");
    }
}