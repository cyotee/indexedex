// SPDX-License-Identifier: BSL-1.1
pragma solidity ^0.8.0;

import {IERC20} from "@crane/contracts/interfaces/IERC20.sol";
import {IStandardExchangeIn} from "contracts/interfaces/IStandardExchangeIn.sol";
import {IStandardExchangeOut} from "contracts/interfaces/IStandardExchangeOut.sol";
import {TestBase_ERC4626StandardExchange} from
    "contracts/test/bases/TestBase_ERC4626StandardExchange.sol";
import {MintableERC20Decimals} from "contracts/test/stubs/MintableERC20Decimals.sol";
import {SimpleYieldERC4626} from "contracts/test/stubs/SimpleYieldERC4626.sol";

/**
 * @title TestBase_ERC4626StandardExchange_Decimals
 * @notice Shared decimal TestBase: protocol-vault asset is `MintableERC20Decimals`; SE vaultShare stays 18.
 */
abstract contract TestBase_ERC4626StandardExchange_Decimals is TestBase_ERC4626StandardExchange {
    MintableERC20Decimals internal underlying;
    SimpleYieldERC4626 internal protocolVault;
    address internal se;
    IStandardExchangeIn internal seIn;
    IStandardExchangeOut internal seOut;
    address internal user = address(0xBEEF);
    address internal attacker;

    function _underlyingDecimals() internal pure virtual returns (uint8);

    /// @dev Raw units of the configured underlying (`human * 10 ** decimals`).
    function _u(uint256 human) internal pure returns (uint256) {
        return human * (10 ** uint256(_underlyingDecimals()));
    }

    function setUp() public virtual override {
        TestBase_ERC4626StandardExchange.setUp();
        attacker = makeAddr("attacker");
        underlying = new MintableERC20Decimals("Underlying", "UND", _underlyingDecimals());
        protocolVault = new SimpleYieldERC4626(underlying);
        se = _deployERC4626SE(address(protocolVault));
        seIn = IStandardExchangeIn(se);
        seOut = IStandardExchangeOut(se);

        underlying.mint(user, _u(1_000_000));
        vm.prank(user);
        underlying.approve(se, type(uint256).max);
        vm.prank(user);
        underlying.approve(address(protocolVault), type(uint256).max);
    }

    function _seedLiquidity(uint256 underlyingIn) internal {
        vm.prank(user);
        seIn.exchangeIn(
            IERC20(address(underlying)),
            underlyingIn,
            IERC20(se),
            0,
            user,
            false,
            block.timestamp
        );
    }
}
