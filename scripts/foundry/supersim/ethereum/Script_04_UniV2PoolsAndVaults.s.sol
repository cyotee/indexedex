// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.0;

import {DeploymentBase} from "../../anvil_sepolia/DeploymentBase.sol";

import {IERC20} from "@crane/contracts/interfaces/IERC20.sol";
import {IERC20MintBurn} from "@crane/contracts/interfaces/IERC20MintBurn.sol";
import {IUniswapV2Pair} from "@crane/contracts/interfaces/protocols/dexes/uniswap/v2/IUniswapV2Pair.sol";

import {IUniswapV2StandardExchangeDFPkg} from "contracts/protocols/dexes/uniswap/v2/UniswapV2StandardExchangeDFPkg.sol";

contract Script_04_UniV2PoolsAndVaults is DeploymentBase {
    uint256 internal constant INITIAL_LIQUIDITY = 10_000e18;
    uint256 internal constant UNBALANCED_RATIO_B = 1_000e18;
    uint256 internal constant UNBALANCED_RATIO_C = 100e18;
    uint256 internal constant INITIAL_WETH = 10e18;
    uint256 internal constant INITIAL_TTC = 10_000e18;

    address private ttA;
    address private ttB;
    address private ttC;

    IUniswapV2StandardExchangeDFPkg private uniV2Pkg;

    IUniswapV2Pair private abPool;
    IUniswapV2Pair private acPool;
    IUniswapV2Pair private bcPool;
    IUniswapV2Pair private uniWethcPool;

    address private abVault;
    address private acVault;
    address private bcVault;
    address private uniWethcVault;

    function run() external {
        _setup();
        _loadPreviousDeployments();

        _logHeader("Ethereum Stage 4: UniV2 Pools, Vaults, Liquidity");

        vm.startBroadcast();
        _deployPools();
        _deployStrategyVaults();
        _mintTestTokensToDeployer();
        _wrapEth();
        _approveRouter();
        _seedUniV2();
        vm.stopBroadcast();

        _exportPoolsJson();
        _exportVaultsJson();
        _exportLiquidityJson();
        _logResults();
    }

    function _loadPreviousDeployments() internal {
        ttA = _readAddress("07_test_tokens.json", "testTokenA");
        ttB = _readAddress("07_test_tokens.json", "testTokenB");
        ttC = _readAddress("07_test_tokens.json", "testTokenC");

        require(ttA != address(0), "Test Token A not found");
        require(ttB != address(0), "Test Token B not found");
        require(ttC != address(0), "Test Token C not found");

        address uniFactory = _readAddress("05_uniswap_v2.json", "uniswapV2Factory");
        address uniRouter = _readAddress("05_uniswap_v2.json", "uniswapV2Router");
        uniV2Pkg = IUniswapV2StandardExchangeDFPkg(_readAddress("05_uniswap_v2.json", "uniswapV2Pkg"));

        require(uniFactory != address(0), "UniswapV2Factory not found");
        require(uniRouter != address(0), "UniswapV2Router not found");
        require(address(uniV2Pkg) != address(0), "UniswapV2Pkg not found");

        _setOurUniswapV2(uniRouter, uniFactory);
    }

    function _deployPools() internal {
        address abPairAddr = uniswapV2Factory.getPair(ttA, ttB);
        if (abPairAddr == address(0)) {
            abPairAddr = uniswapV2Factory.createPair(ttA, ttB);
        }
        abPool = IUniswapV2Pair(abPairAddr);

        address acPairAddr = uniswapV2Factory.getPair(ttA, ttC);
        if (acPairAddr == address(0)) {
            acPairAddr = uniswapV2Factory.createPair(ttA, ttC);
        }
        acPool = IUniswapV2Pair(acPairAddr);

        address bcPairAddr = uniswapV2Factory.getPair(ttB, ttC);
        if (bcPairAddr == address(0)) {
            bcPairAddr = uniswapV2Factory.createPair(ttB, ttC);
        }
        bcPool = IUniswapV2Pair(bcPairAddr);

        address wethcPairAddr = uniswapV2Factory.getPair(address(weth), ttC);
        if (wethcPairAddr == address(0)) {
            wethcPairAddr = uniswapV2Factory.createPair(address(weth), ttC);
        }
        uniWethcPool = IUniswapV2Pair(wethcPairAddr);
    }

    function _deployStrategyVaults() internal {
        abVault = uniV2Pkg.deployVault(abPool);
        acVault = uniV2Pkg.deployVault(acPool);
        bcVault = uniV2Pkg.deployVault(bcPool);
        uniWethcVault = uniV2Pkg.deployVault(uniWethcPool);
    }

    function _mintTestTokensToDeployer() internal {
        uint256 mintAmount = 1_000_000e18;
        IERC20MintBurn(ttA).mint(deployer, mintAmount);
        IERC20MintBurn(ttB).mint(deployer, mintAmount);
        IERC20MintBurn(ttC).mint(deployer, mintAmount);
    }

    function _wrapEth() internal {
        uint256 haveWeth = IERC20(address(weth)).balanceOf(deployer);
        if (haveWeth < INITIAL_WETH) {
            weth.deposit{value: INITIAL_WETH - haveWeth}();
        }
    }

    function _approveMax(address token, address spender) internal {
        IERC20(token).approve(spender, 0);
        IERC20(token).approve(spender, type(uint256).max);
    }

    function _approveRouter() internal {
        _approveMax(ttA, address(uniswapV2Router));
        _approveMax(ttB, address(uniswapV2Router));
        _approveMax(ttC, address(uniswapV2Router));
        _approveMax(address(weth), address(uniswapV2Router));
    }

    function _seedUniV2() internal {
        uint256 deadline = block.timestamp + 1 hours;
        uniswapV2Router.addLiquidity(ttA, ttB, INITIAL_LIQUIDITY, INITIAL_LIQUIDITY, 0, 0, deployer, deadline);
        uniswapV2Router.addLiquidity(ttA, ttC, INITIAL_LIQUIDITY, UNBALANCED_RATIO_B, 0, 0, deployer, deadline);
        uniswapV2Router.addLiquidity(ttB, ttC, INITIAL_LIQUIDITY, UNBALANCED_RATIO_C, 0, 0, deployer, deadline);
        uniswapV2Router.addLiquidity(address(weth), ttC, INITIAL_WETH, INITIAL_TTC, 0, 0, deployer, deadline);
    }

    function _exportPoolsJson() internal {
        string memory json;
        json = vm.serializeAddress("", "abPool", address(abPool));
        json = vm.serializeAddress("", "acPool", address(acPool));
        json = vm.serializeAddress("", "bcPool", address(bcPool));
        json = vm.serializeAddress("", "uniWethcPool", address(uniWethcPool));
        _writeJson(json, "08_pools.json");
    }

    function _exportVaultsJson() internal {
        string memory json;
        json = vm.serializeAddress("", "abVault", abVault);
        json = vm.serializeAddress("", "acVault", acVault);
        json = vm.serializeAddress("", "bcVault", bcVault);
        json = vm.serializeAddress("", "uniWethcVault", uniWethcVault);
        _writeJson(json, "09_strategy_vaults.json");
    }

    function _exportLiquidityJson() internal {
        string memory json;
        json = vm.serializeUint("", "initialLiquidity", INITIAL_LIQUIDITY);
        json = vm.serializeUint("", "unbalancedRatioB", UNBALANCED_RATIO_B);
        json = vm.serializeUint("", "unbalancedRatioC", UNBALANCED_RATIO_C);
        json = vm.serializeUint("", "initialWeth", INITIAL_WETH);
        json = vm.serializeUint("", "initialTtc", INITIAL_TTC);
        _writeJson(json, "10_base_liquidity.json");
    }

    function _logResults() internal view {
        _logAddress("UniV2 A-B Pool:", address(abPool));
        _logAddress("UniV2 A-C Pool:", address(acPool));
        _logAddress("UniV2 B-C Pool:", address(bcPool));
        _logAddress("UniV2 A-B Vault:", abVault);
        _logAddress("UniV2 A-C Vault:", acVault);
        _logAddress("UniV2 B-C Vault:", bcVault);
        _logAddress("UniV2 WETH/TTC Pool:", address(uniWethcPool));
        _logAddress("UniV2 WETH/TTC Vault:", uniWethcVault);
        _logComplete("Ethereum Stage 4");
    }
}