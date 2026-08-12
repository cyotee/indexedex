// SPDX-License-Identifier: BSL-1.1
pragma solidity ^0.8.0;

import {IERC20} from "@crane/contracts/interfaces/IERC20.sol";
import {
    TestBase_UniswapV4OrbitalSwapHook
} from "contracts/hooks/uniswap/v4/orbital/TestBase_UniswapV4OrbitalSwapHook.sol";
import {
    IUniswapV4OrbitalSwapHook
} from "contracts/hooks/uniswap/v4/orbital/interfaces/IUniswapV4OrbitalSwapHook.sol";
import {ResearchTelemetry} from "scripts/foundry/research/harness/ResearchTelemetry.sol";

/**
 * @title ResearchFixture_OrbitalHook
 * @notice Hermetic research world for Orbital Swap Hook Mode H scenarios.
 * @dev Call `bootstrapResearch()` on a *deployed* fixture instance (setUp is empty for script use).
 */
contract ResearchFixture_OrbitalHook is TestBase_UniswapV4OrbitalSwapHook {
    ResearchTelemetry.RunPaths public runPaths;
    uint256 public step;
    bool public telemetryReady;

    uint256 public initR0;
    uint256 public initR1;
    uint256 public initR2;
    uint256 public initLpSupply;
    uint256 public researchBookLp;

    uint256 public constant DEFAULT_SEED = 500 ether;
    uint256 public constant TRADE_SIZE = 1 ether;
    uint256 public constant TRADE_STEPS = 24;

    /// @dev Silence Foundry auto-setUp when used from forge script via `new`.
    function setUp() public virtual override {
        // intentionally empty — use bootstrapResearch()
    }

    function bootstrapResearch() public {
        TestBase_UniswapV4OrbitalSwapHook.setUp();
    }

    function seedLiquidity(uint256 perLeg_) public returns (uint256 shares_) {
        shares_ = _seedThreeLeg(perLeg_);
        researchBookLp = IERC20(hook).balanceOf(user);
        initR0 = orbital.reserveOf(address(token0));
        initR1 = orbital.reserveOf(address(token1));
        initR2 = orbital.reserveOf(address(token2));
        initLpSupply = IERC20(hook).totalSupply();
    }

    function setDexFee(uint256 feeWad_) public {
        _setDexFee(feeWad_);
    }

    function swapExactIn(address tokenIn, address tokenOut, uint256 amountIn) public {
        _swapExactIn(tokenIn, tokenOut, amountIn);
    }

    function researchUser() public view returns (address) {
        return user;
    }

    function hookAddress() public view returns (address) {
        return hook;
    }

    function orbitalHook() public view returns (IUniswapV4OrbitalSwapHook) {
        return orbital;
    }

    function radius() public view returns (uint256) {
        return orbital.radius();
    }

    function reserveOf(address token_) public view returns (uint256) {
        return orbital.reserveOf(token_);
    }

    function tokenAddresses() public view returns (address t0, address t1, address t2) {
        return (address(token0), address(token1), address(token2));
    }

    function telemetryPaths() public view returns (ResearchTelemetry.RunPaths memory) {
        return runPaths;
    }

    function currentStep() public view returns (uint256) {
        return step;
    }

    function initTelemetry(string memory runId_) public {
        runPaths = ResearchTelemetry.initRun("uniswapV4/hooks/orbital", runId_);
        step = 0;
        telemetryReady = true;
        ResearchTelemetry.writeMeta(
            runPaths,
            string.concat(
                '{"campaign":"uniswapV4/hooks/orbital","runId":"',
                runId_,
                '","product":"orbitalSwapHook","profileHint":"orbital"}'
            )
        );
    }

    function sample(string memory tag_) public {
        require(telemetryReady, "telemetry not ready");
        ResearchTelemetry.appendLine(runPaths, _sampleJson(tag_));
        unchecked {
            ++step;
        }
    }

    function _sampleJson(string memory tag_) internal view returns (string memory) {
        uint256 r0 = orbital.reserveOf(address(token0));
        uint256 r1 = orbital.reserveOf(address(token1));
        uint256 r2 = orbital.reserveOf(address(token2));
        uint256 lpSupply = IERC20(hook).totalSupply();
        uint256 bookLp = IERC20(hook).balanceOf(user);
        uint256 radius_ = orbital.radius();

        // Raw mid ratios (1e18 scale): r_j / r_i when r_i > 0
        uint256 mid01 = r0 > 0 ? (r1 * 1e18) / r0 : 0;
        uint256 mid10 = r1 > 0 ? (r0 * 1e18) / r1 : 0;
        uint256 midIndex01 = initR0 > 0 && initR1 > 0 && r0 > 0
            ? ((r1 * 1e18) / r0) * 1e18 / ((initR1 * 1e18) / initR0)
            : 1e18;

        return string.concat(
            "{",
            '"step":',
            ResearchTelemetry.u(step),
            ',"tag":"',
            tag_,
            '","radius":',
            ResearchTelemetry.u(radius_),
            ',"r0":',
            ResearchTelemetry.u(r0),
            ',"r1":',
            ResearchTelemetry.u(r1),
            ',"r2":',
            ResearchTelemetry.u(r2),
            ',"lpSupply":',
            ResearchTelemetry.u(lpSupply),
            ',"bookLp":',
            ResearchTelemetry.u(bookLp),
            ',"mid01":',
            ResearchTelemetry.u(mid01),
            ',"mid10":',
            ResearchTelemetry.u(mid10),
            ',"midIndex01":',
            ResearchTelemetry.u(midIndex01),
            ',"initR0":',
            ResearchTelemetry.u(initR0),
            ',"initR1":',
            ResearchTelemetry.u(initR1),
            ',"initR2":',
            ResearchTelemetry.u(initR2),
            ',"initLpSupply":',
            ResearchTelemetry.u(initLpSupply),
            "}"
        );
    }

    /// @dev Preview vs execution for exact-in; returns (preview, got).
    function measurePreviewExactIn(address tokenIn, address tokenOut, uint256 amountIn)
        public
        returns (uint256 preview_, uint256 exec_)
    {
        preview_ = orbital.previewSwapExactIn(tokenIn, tokenOut, amountIn);
        uint256 beforeOut = IERC20(tokenOut).balanceOf(user);
        _swapExactIn(tokenIn, tokenOut, amountIn);
        exec_ = IERC20(tokenOut).balanceOf(user) - beforeOut;
    }
}
