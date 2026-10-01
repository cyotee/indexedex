// SPDX-License-Identifier: BSL-1.1
pragma solidity ^0.8.0;

import {TestBase_UniswapV4FullSpreadHooklessStandardExchangeVault_Acceptance as Acceptance} from "contracts/vaults/standard/exchange/protocols/uniswap/v4/fullSpread/hookless/test/bases/TestBase_UniswapV4FullSpreadHooklessStandardExchangeVault_Acceptance.sol";
import {TestBase_FullSpreadG5GuardClosure as Guards} from "contracts/test/bases/TestBase_FullSpreadG5GuardClosure.sol";
import {FullSpreadG5GuardToken} from "contracts/test/stubs/FullSpreadG5GuardToken.sol";
import {IERC20} from "@crane/contracts/interfaces/IERC20.sol";
import {IVaultRegistryDisableManager} from "contracts/interfaces/IVaultRegistryDisableManager.sol";
import {IVaultFeeOracleManager} from "contracts/interfaces/IVaultFeeOracleManager.sol";
import {StateLibrary} from "@crane/contracts/protocols/dexes/uniswap/v4/libraries/StateLibrary.sol";
import {PoolIdLibrary} from "@crane/contracts/protocols/dexes/uniswap/v4/types/PoolId.sol";

// tag::HooklessG5GuardClosureTest[]
/// @notice G5 legacy guard preservation on the real hookless registry proxy.
contract HooklessG5GuardClosureTest is Acceptance, Guards {
    /// @notice Reuse the complete production fixture; only the underlying is hostile.
    function setUp() public override(Acceptance) {
        Acceptance.setUp(); _g5Initialize(vault, token0, token1, poolManager, address(0));
    }
    function _deployTokenA() internal override returns (IERC20) {
        g5Hostile = new FullSpreadG5GuardToken(); return IERC20(address(g5Hostile));
    }
    function _g5Blocked(bytes memory data_) internal override returns (bytes memory) { return _nested(data_); }
    function _g5DisablePackage(bool disabled_) internal override {
        vm.prank(owner);
        IVaultRegistryDisableManager(address(indexedexManager)).setPackageDisabled(address(uniswapV4StandardExchangeDFPkg), disabled_);
    }
    function _g5HistoryTrade(bool direction_, uint256 amount_) internal override {
        (uint160 beforePrice,,,) = StateLibrary.getSlot0(poolManager, PoolIdLibrary.toId(poolKey));
        _externalSwap(direction_, amount_);
        (uint160 afterPrice,,,) = StateLibrary.getSlot0(poolManager, PoolIdLibrary.toId(poolKey));
        assertTrue(beforePrice != afterPrice, "G5 actual external movement");
    }
    function _g5HistorySleeve(uint256 percentage_) internal override {
        vm.prank(owner);
        IVaultFeeOracleManager(address(indexedexManager)).setLiquidReservePercentageOfVault(address(vault), percentage_);
    }
}
// end::HooklessG5GuardClosureTest[]
