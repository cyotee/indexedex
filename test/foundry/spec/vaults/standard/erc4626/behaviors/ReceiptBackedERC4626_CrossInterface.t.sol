// SPDX-License-Identifier: BSL-1.1
pragma solidity ^0.8.0;

import {IERC20} from "@crane/contracts/interfaces/IERC20.sol";
import {TestBase_ERC4626StandardExchange} from
    "contracts/test/bases/TestBase_ERC4626StandardExchange.sol";
import {TestBase_AaveV3StataStandardExchange_Decimals} from
    "contracts/test/bases/TestBase_AaveV3StataStandardExchange_Decimals.sol";
import {SimpleMintableERC20} from "contracts/test/stubs/SimpleMintableERC20.sol";
import {SimpleYieldERC4626} from "contracts/test/stubs/SimpleYieldERC4626.sol";
import {Behavior_ReceiptBackedERC4626_CrossInterface} from
    "test/foundry/spec/vaults/standard/erc4626/behaviors/Behavior_ReceiptBackedERC4626_CrossInterface.sol";

/// @notice R14.17 host: generic ERC-4626 SE family (18-dec SimpleYield receipt).
contract ReceiptBackedERC4626_CrossInterface_Generic is
    TestBase_ERC4626StandardExchange,
    Behavior_ReceiptBackedERC4626_CrossInterface
{
    SimpleMintableERC20 internal gUnderlying;
    SimpleYieldERC4626 internal gVault;
    address internal gSe;
    address internal gActor = address(0xA11CE);

    function setUp()
        public
        override(TestBase_ERC4626StandardExchange, Behavior_ReceiptBackedERC4626_CrossInterface)
    {
        TestBase_ERC4626StandardExchange.setUp();
        gUnderlying = new SimpleMintableERC20("Underlying", "UND");
        gVault = new SimpleYieldERC4626(gUnderlying);
        gSe = _deployERC4626SE(address(gVault));
    }

    function _se() internal view override returns (address) { return gSe; }
    function _receipt() internal view override returns (IERC20) { return IERC20(address(gVault)); }
    function _underlyingToken() internal view override returns (IERC20) { return IERC20(address(gUnderlying)); }
    function _actor() internal view override returns (address) { return gActor; }

    function _giveActorReceipts(uint256 human) internal override returns (uint256 receiptsOut) {
        uint256 amt = human * 1e18;
        gUnderlying.mint(gActor, amt);
        vm.startPrank(gActor);
        gUnderlying.approve(address(gVault), type(uint256).max);
        receiptsOut = gVault.deposit(amt, gActor);
        IERC20(address(gVault)).approve(gSe, type(uint256).max);
        vm.stopPrank();
    }
}

/// @notice R14.17 host: Aave V3 Stata SE family (real StataTokenV2 receipt over 6-dec usdx).
contract ReceiptBackedERC4626_CrossInterface_Stata is
    TestBase_AaveV3StataStandardExchange_Decimals,
    Behavior_ReceiptBackedERC4626_CrossInterface
{
    function _underlyingDecimals() internal pure override returns (uint8) { return 6; }

    function setUp()
        public
        override(TestBase_AaveV3StataStandardExchange_Decimals, Behavior_ReceiptBackedERC4626_CrossInterface)
    {
        TestBase_AaveV3StataStandardExchange_Decimals.setUp();
    }

    function _se() internal view override returns (address) { return realVault; }
    function _receipt() internal view override returns (IERC20) { return IERC20(realStata); }
    function _underlyingToken() internal view override returns (IERC20) { return IERC20(realBase); }
    function _actor() internal view override returns (address) { return address(this); }

    function _giveActorReceipts(uint256 human) internal override returns (uint256 receiptsOut) {
        receiptsOut = _acquireStata(address(this), _u(human));
        IERC20(realStata).approve(realVault, type(uint256).max);
    }
}
