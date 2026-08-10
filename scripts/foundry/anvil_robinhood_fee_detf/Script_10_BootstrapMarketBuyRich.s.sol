// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.0;

import {DeploymentBase} from "./DeploymentBase.sol";
import {RobinhoodCanonicalLib} from "./RobinhoodCanonicalLib.sol";
import {FixtureEconomics} from "./FixtureEconomics.sol";

import {IERC20} from "@crane/contracts/interfaces/IERC20.sol";
import {IWETH9} from "@crane/contracts/protocols/dexes/uniswap/v3/periphery/interfaces/external/IWETH9.sol";

/// @dev SwapRouter02-style exactInputSingle (no deadline) - live pons dexConfig.routerRequiresDeadline=false.
interface ISwapRouter02ExactIn {
    struct ExactInputSingleParams {
        address tokenIn;
        address tokenOut;
        uint24 fee;
        address recipient;
        uint256 amountIn;
        uint256 amountOutMinimum;
        uint160 sqrtPriceLimitX96;
    }

    function exactInputSingle(ExactInputSingleParams calldata params) external payable returns (uint256 amountOut);
}

/// @title Script_10_BootstrapMarketBuyRich
/// @notice Large WETH->RICH buy on pons V3 pool (router pin preferred; UR optional later).
contract Script_10_BootstrapMarketBuyRich is DeploymentBase {
    string internal constant PONS_FILE = "04_pons_rich.json";
    string internal constant ARTIFACT_FILE = "10_market_buy_rich.json";

    address private rich;
    address private pool;
    address private weth;
    address private router;
    uint256 private wethSpent;
    uint256 private richBought;
    uint24 private poolFee;
    uint256 private restrictionsEndBlock;

    function run() external {
        _loadConfig();
        _requireRobinhoodChain();
        RobinhoodCanonicalLib.requireCanonicalPins();
        _loadPrior();
        _logHeader("Stage 10: Market buy RICH (large WETH in)");

        if (_loadExisting()) {
            _exportJson();
            _logResults();
            return;
        }

        // Wait out pons launch protection if needed (forge broadcast uses live block; also roll for sim).
        if (block.number <= restrictionsEndBlock) {
            vm.roll(restrictionsEndBlock + 1);
        }

        wethSpent = FixtureEconomics.largeRichBuyWeth();
        router = FixtureEconomics.PONS_V3_SWAP_ROUTER;
        if (router.code.length == 0) {
            // Fallback to ROBINHOOD_MAIN SwapRouter02 pin if different.
            router = RobinhoodCanonicalLib.v3SwapRouter();
        }
        require(router.code.length > 0, "swap router missing code");

        uint256 richBefore = IERC20(rich).balanceOf(deployer);

        vm.startBroadcast();
        IWETH9(weth).deposit{value: wethSpent}();
        IERC20(weth).approve(router, wethSpent);
        // Wide minOut for local fork depth / bootstrap.
        ISwapRouter02ExactIn(router).exactInputSingle(
            ISwapRouter02ExactIn.ExactInputSingleParams({
                tokenIn: weth,
                tokenOut: rich,
                fee: poolFee == 0 ? 10000 : poolFee,
                recipient: deployer,
                amountIn: wethSpent,
                amountOutMinimum: 0,
                sqrtPriceLimitX96: 0
            })
        );
        vm.stopBroadcast();

        richBought = IERC20(rich).balanceOf(deployer) - richBefore;
        require(richBought > 0, "RICH buy produced zero tokens");

        _exportJson();
        _logResults();
    }

    function _loadPrior() internal {
        rich = _readAddress(PONS_FILE, "rich");
        pool = _readAddress(PONS_FILE, "pool");
        weth = RobinhoodCanonicalLib.weth();
        (restrictionsEndBlock,) = _readUintSafe(PONS_FILE, "restrictionsEndBlock");
        (uint256 feeU,) = _readUintSafe(PONS_FILE, "poolFee");
        poolFee = uint24(feeU == 0 ? 10000 : feeU);
        require(rich != address(0), "missing rich");
    }

    function _loadExisting() internal returns (bool) {
        if (_force()) return false;
        (uint256 spent, bool okS) = _readUintSafe(ARTIFACT_FILE, "wethSpent");
        (uint256 bought, bool okB) = _readUintSafe(ARTIFACT_FILE, "richBought");
        if (!okS || !okB || spent == 0 || bought == 0) return false;
        // Resume only if deployer still holds RICH from prior buy.
        if (IERC20(_readAddress(PONS_FILE, "rich")).balanceOf(deployer) == 0) return false;
        wethSpent = spent;
        richBought = bought;
        (router,) = _readAddressSafe(ARTIFACT_FILE, "router");
        return true;
    }

    function _exportJson() internal {
        string memory json;
        json = vm.serializeAddress("buy", "rich", rich);
        json = vm.serializeAddress("buy", "pool", pool);
        json = vm.serializeAddress("buy", "weth", weth);
        json = vm.serializeAddress("buy", "router", router);
        json = vm.serializeUint("buy", "wethSpent", wethSpent);
        json = vm.serializeUint("buy", "richBought", richBought);
        json = vm.serializeUint("buy", "poolFee", uint256(poolFee));
        json = vm.serializeUint("buy", "chainId", block.chainid);
        json = vm.serializeString("buy", "notes", "V3 SwapRouter02 exactInputSingle; minOut=0 local");
        _writeJson(json, ARTIFACT_FILE);
    }

    function _logResults() internal view {
        _logUint("wethSpent:", wethSpent);
        _logUint("richBought:", richBought);
        _logAddress("router:", router);
        _logComplete("Stage 10");
    }
}
