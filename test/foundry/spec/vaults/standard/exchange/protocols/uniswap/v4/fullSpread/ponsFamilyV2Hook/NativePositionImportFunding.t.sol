// SPDX-License-Identifier: BSL-1.1
pragma solidity ^0.8.0;
import {TestBase_UniswapV4FullSpreadPonsFamilyHook_Launch as Launch} from "contracts/vaults/standard/exchange/protocols/uniswap/v4/fullSpread/ponsFamilyV2Hook/test/bases/TestBase_UniswapV4FullSpreadPonsFamilyHook_Launch.sol";
import {TestBase_UniswapV4FullSpreadNativeImport as ImportChecks} from "contracts/test/bases/TestBase_UniswapV4FullSpreadNativeImport.sol";

contract UniswapV4FullSpreadPonsFamilyHookNativePositionImportFundingTest is Launch, ImportChecks {
    function _nativeLaunch() internal pure override returns (bool) { return true; }
    function setUp() public override(Launch) {
        Launch.setUp();
        // Import activates this otherwise-empty registered vault; never call _activatePonsSe here.
        _startImport(ponsSe, poolManager, ponsPositionManager, permit2, weth, graduatedPoolKey);
    }
    function test_nativeImportActualFundingExcludesPriorSleeve() public { _nativeImportFundingAndDonationExclusion(); }
    function test_nativeImportLateGuardRestoresNftAndBalances() public { _nativeImportRollback(); }
}
