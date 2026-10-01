// SPDX-License-Identifier: BSL-1.1
pragma solidity ^0.8.0;
import {TestBase_UniswapV4FullSpreadHooklessStandardExchangeVault_Acceptance as Acceptance} from "contracts/vaults/standard/exchange/protocols/uniswap/v4/fullSpread/hookless/test/bases/TestBase_UniswapV4FullSpreadHooklessStandardExchangeVault_Acceptance.sol";
import {TestBase_UniswapV4FullSpreadCrossModeCampaign as Campaign} from "contracts/test/bases/TestBase_UniswapV4FullSpreadCrossModeCampaign.sol";

contract UniswapV4FullSpreadHooklessStandardExchangeVaultCrossModeStatefulCampaignTest is Acceptance, Campaign {
    function setUp() public override(Acceptance) {
        Acceptance.setUp();
        _bootstrap();
        _startCampaign(vault, poolManager, poolKey, [unit0 / 1_000, unit1 / 1_000]);
    }

    function _campaignBlocked(bytes memory data_) internal override returns (bytes memory) { return _nested(data_); }

    function testFuzz_crossModeStatefulCampaign(uint256 seed_) public { _runCampaign(seed_); }
}
