// SPDX-License-Identifier: BSL-1.1
pragma solidity ^0.8.0;
import {TestBase_UniswapV4FullSpreadPonsFamilyHook_LaunchNested as Launch} from "contracts/vaults/standard/exchange/protocols/uniswap/v4/fullSpread/ponsFamilyV2Hook/test/bases/TestBase_UniswapV4FullSpreadPonsFamilyHook_LaunchNested.sol";
import {TestBase_UniswapV4FullSpreadPonsFamilyHook_Launch as LaunchBase} from "contracts/vaults/standard/exchange/protocols/uniswap/v4/fullSpread/ponsFamilyV2Hook/test/bases/TestBase_UniswapV4FullSpreadPonsFamilyHook_Launch.sol";
import {TestBase_UniswapV4FullSpreadCrossModeCampaign as Campaign} from "contracts/test/bases/TestBase_UniswapV4FullSpreadCrossModeCampaign.sol";
import {Currency} from "@crane/contracts/protocols/dexes/uniswap/v4/types/Currency.sol";

contract UniswapV4FullSpreadPonsFamilyHookCrossModeStatefulCampaignTest is Launch, Campaign {
    function setUp() public override(LaunchBase) {
        LaunchBase.setUp();
        _activatePonsSe();
        _wrapWeth(address(this), 1 ether);
        bool token0IsLaunch = Currency.unwrap(graduatedPoolKey.currency0) == launchToken;
        _startCampaign(ponsSe, poolManager, graduatedPoolKey,
            [token0IsLaunch ? uint256(1e16) : uint256(1e10), token0IsLaunch ? uint256(1e10) : uint256(1e16)]);
    }

    function _campaignBlocked(bytes memory data_) internal override returns (bytes memory) { return _launchBlocked(data_); }
    function _campaignHookRates() internal pure override returns (uint16, uint16) { return (100, 100); }

    function testFuzz_crossModeStatefulCampaign(uint256 seed_) public { _runCampaign(seed_); }
}
