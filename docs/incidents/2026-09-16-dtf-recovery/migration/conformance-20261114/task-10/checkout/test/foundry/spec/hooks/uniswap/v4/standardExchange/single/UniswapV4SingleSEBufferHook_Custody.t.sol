// SPDX-License-Identifier: BSL-1.1
pragma solidity ^0.8.24;

import {IERC20} from "@crane/contracts/interfaces/IERC20.sol";
import {IVaultRegistryDisableManager} from "contracts/interfaces/IVaultRegistryDisableManager.sol";
import {IVaultRegistryDisableQuery} from "contracts/interfaces/IVaultRegistryDisableQuery.sol";
import {CustomRevert} from "@crane/contracts/protocols/dexes/uniswap/v4/libraries/CustomRevert.sol";
import {Hooks} from "@crane/contracts/protocols/dexes/uniswap/v4/libraries/Hooks.sol";
import {IHooks} from "@crane/contracts/protocols/dexes/uniswap/v4/interfaces/IHooks.sol";
import {SwapParams} from "@crane/contracts/protocols/dexes/uniswap/v4/types/PoolOperation.sol";
import {
    TestBase_UniswapV4SingleStandardExchangeBufferHook as TestBase
} from "contracts/hooks/uniswap/v4/standardExchange/single/TestBase_UniswapV4SingleStandardExchangeBufferHook.sol";

/// @notice Four-mode custody and disable tests against the installed H1 proxy and real ERC4626 SE.
contract UniswapV4SingleSEBufferHook_Custody_Test is TestBase {
    function _book(uint256 offset_) internal view returns (uint256) {
        bytes32 slot_ = keccak256(
            abi.encode(uint256(keccak256("indexedex.hooks.uv4.single.se.buffer.hook.storage")) - 1)
        ) & ~bytes32(uint256(0xff));
        return uint256(vm.load(hook, bytes32(uint256(slot_) + offset_)));
    }

    function _state() internal view returns (bytes memory) {
        return abi.encode(
            pairToken.balanceOf(hook), IERC20(se).balanceOf(hook),
            pairToken.balanceOf(user), IERC20(se).balanceOf(user),
            IERC20(se).totalSupply(), pairToken.allowance(hook, se), IERC20(se).allowance(hook, se),
            _book(5), _book(6), _book(7)
        );
    }

    /// @notice Zero-refund conversions preserve ambient custody in all four installed modes.
    function test_fourModes_zeroRefundLeavesAmbientUnbooked() public {
        pairToken.mint(hook, 17 ether);
        vm.prank(user);
        IERC20(se).transfer(hook, 3 ether);
        uint256 pairs_ = pairToken.balanceOf(hook);
        uint256 shares_ = IERC20(se).balanceOf(hook);
        assertEq(address(uint160(_book(5))), address(indexedexManager));
        _wrapExactIn(8 ether);
        _assertHookFlatDelta(pairs_, shares_);
        _unwrapExactIn(3 ether);
        _assertHookFlatDelta(pairs_, shares_);
        _wrapExactOut(2 ether);
        _assertHookFlatDelta(pairs_, shares_);
        _unwrapExactOut(1 ether);
        _assertHookFlatDelta(pairs_, shares_);
        assertEq(_book(6), 0, "ambient pair never credited");
        assertEq(_book(7), 0, "ambient shares never credited");
        assertEq(pairToken.allowance(hook, se), 0);
        assertEq(IERC20(se).allowance(hook, se), 0);
    }

    function test_disabledAddress_allFourModes() public { _disabledModes(false); }
    function test_disabledPackage_allFourModes() public { _disabledModes(true); }

    function _disabledModes(bool package_) internal {
        address pkg_ = IVaultRegistryDisableQuery(address(indexedexManager)).packageOfVault(se);
        vm.prank(owner);
        if (package_) IVaultRegistryDisableManager(address(indexedexManager)).setPackageDisabled(pkg_, true);
        else IVaultRegistryDisableManager(address(indexedexManager)).setVaultAddressDisabled(se, true);

        bytes memory before_ = _state();
        bytes memory reason_ = abi.encodeWithSelector(
            CustomRevert.WrappedError.selector, hook, IHooks.beforeSwap.selector,
            abi.encodeWithSelector(IVaultRegistryDisableQuery.VaultDisabled.selector, se),
            abi.encodePacked(Hooks.HookCallFailed.selector)
        );
        vm.expectRevert(reason_);
        this.wrapWhileDisabled(false);
        assertEq(_state(), before_, "exact-in wrap rolls back");
        vm.expectRevert(reason_);
        this.wrapWhileDisabled(true);
        assertEq(_state(), before_, "exact-out wrap rolls back");

        assertGt(_unwrapExactIn(1 ether), 0, "disabled exact-in withdrawal remains available");
        assertGt(_unwrapExactOut(1 ether), 0, "disabled exact-out withdrawal remains available");
        _assertHookFlat();
        assertEq(_book(6), 0);
        assertEq(_book(7), 0);

        vm.prank(owner);
        if (package_) IVaultRegistryDisableManager(address(indexedexManager)).setPackageDisabled(pkg_, false);
        else IVaultRegistryDisableManager(address(indexedexManager)).setVaultAddressDisabled(se, false);
        assertGt(_wrapExactIn(1 ether), 0);
        assertGt(_wrapExactOut(1 ether), 0);
    }

    /// @dev Do not pre-quote through a disabled SE; test the actual installed callback in both modes.
    function wrapWhileDisabled(bool exactOut_) external {
        bool zfo_ = _isWrapZFO();
        SwapParams memory params_ = SwapParams({
            zeroForOne: zfo_,
            amountSpecified: exactOut_ ? int256(1 ether) : -int256(1 ether),
            sqrtPriceLimitX96: _sqrtLimit(zfo_)
        });
        vm.prank(user);
        if (exactOut_) swapRouter.swapExactOut(poolKey, params_, 10 ether, "");
        else swapRouter.swapExactIn(poolKey, params_, "");
    }
}
