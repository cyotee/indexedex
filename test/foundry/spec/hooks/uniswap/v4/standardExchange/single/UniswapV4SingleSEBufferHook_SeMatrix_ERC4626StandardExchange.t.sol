// SPDX-License-Identifier: BSL-1.1
pragma solidity ^0.8.0;

import {IERC20} from "@crane/contracts/interfaces/IERC20.sol";
import {IBasicVault} from "contracts/interfaces/IBasicVault.sol";
import {MintableERC20Decimals} from "contracts/test/stubs/MintableERC20Decimals.sol";
import {UnderConsumeERC4626} from "contracts/test/stubs/UnderConsumeERC4626.sol";
import {SeMatrixFixture} from "test/foundry/spec/hooks/uniswap/v4/standardExchange/SeMatrixFixture.sol";
import {SeMatrix_ERC4626Fixture} from "test/foundry/spec/hooks/uniswap/v4/standardExchange/SeMatrix_ERC4626Fixture.sol";
import {
    UniswapV4SingleSEBufferHook_SeMatrixBehavior
} from "test/foundry/spec/hooks/uniswap/v4/standardExchange/single/UniswapV4SingleSEBufferHook_SeMatrixBehavior.sol";

/// @notice D20: non-CP single × ERC4626StandardExchange (COMPATIBLE). Face: 18-decimal underlying
///         of a capped/pausable ERC-4626 stub wrapped by the production ERC-4626 SE package; the
///         hook is deployed through its package on that face and SE (WP0, moved onto the hook
///         TestBase from the former receipt-backed placeholder).
contract UniswapV4SingleSEBufferHook_SeMatrix_ERC4626StandardExchange is UniswapV4SingleSEBufferHook_SeMatrixBehavior {
    function _newFixture() internal override returns (SeMatrixFixture) {
        return new SeMatrix_ERC4626Fixture(_ctx(), erc4626StandardExchangeDFPkg, 18);
    }

    /// @dev Parity with the six other ERC-4626 rows: an under-consuming protocol vault leaves dust
    ///      on the SE; the wrapper pays its full input and is never refunded from it.
    function test_underConsumption_leaveDust_doesNotPayCaller() public {
        UnderConsumeERC4626 proto = new UnderConsumeERC4626(MintableERC20Decimals(face));
        proto.setLeaveDust(_f(1));
        address underSe = _deployERC4626SE(address(proto));
        se = underSe;
        _deployRowHook(_defaultPkgArgs());
        uint256 userFace = IERC20(face).balanceOf(user);
        assertGt(_wrapExactIn(_f(100)), 0, "big wrap through the under-consuming SE");
        _wrapExactIn(_f(5));
        assertEq(userFace - IERC20(face).balanceOf(user), _f(105), "under-consume leftover is not the wrapper's refund");
        assertEq(IERC20(face).balanceOf(hook), 0, "hook holds no leftover");
        assertGt(IBasicVault(underSe).reserveOfToken(face), 0, "dust is booked on the SE");
    }
}
