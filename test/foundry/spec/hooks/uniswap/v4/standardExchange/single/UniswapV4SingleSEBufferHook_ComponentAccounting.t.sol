// SPDX-License-Identifier: BSL-1.1
pragma solidity ^0.8.24;

import {IERC20} from "@crane/contracts/interfaces/IERC20.sol";
import {IVaultRegistryDisableManager} from "contracts/interfaces/IVaultRegistryDisableManager.sol";
import {IVaultRegistryDisableQuery} from "contracts/interfaces/IVaultRegistryDisableQuery.sol";
import {IVaultFeeOracleQuery} from "contracts/interfaces/IVaultFeeOracleQuery.sol";
import {CustomRevert} from "@crane/contracts/protocols/dexes/uniswap/v4/libraries/CustomRevert.sol";
import {Hooks} from "@crane/contracts/protocols/dexes/uniswap/v4/libraries/Hooks.sol";
import {IHooks} from "@crane/contracts/protocols/dexes/uniswap/v4/interfaces/IHooks.sol";
import {IPoolManager} from "@crane/contracts/protocols/dexes/uniswap/v4/interfaces/IPoolManager.sol";
import {IUnlockCallback} from "@crane/contracts/protocols/dexes/uniswap/v4/interfaces/callback/IUnlockCallback.sol";
import {PoolKey} from "@crane/contracts/protocols/dexes/uniswap/v4/types/PoolKey.sol";
import {SwapParams} from "@crane/contracts/protocols/dexes/uniswap/v4/types/PoolOperation.sol";
import {IStandardExchangeIn} from "@crane/contracts/interfaces/IStandardExchangeIn.sol";
import {IStandardExchangeOut} from "@crane/contracts/interfaces/IStandardExchangeOut.sol";
import {IVaultRegistryVaultManager} from "contracts/interfaces/IVaultRegistryVaultManager.sol";
import {IStandardVault} from "contracts/interfaces/IStandardVault.sol";
import {HookComponentCustodyBehavior} from "../HookComponentAccountingBehavior.sol";
import {SeMatrix_FullSpreadV4Fixture} from "../SeMatrix_FullSpreadV4Fixture.sol";
import {UniswapV4SingleSEBufferHook_SeMatrix_UniswapV4FullSpreadStandardExchangeVault as FullSpreadRow} from "./UniswapV4SingleSEBufferHook_SeMatrix_UniswapV4FullSpreadStandardExchangeVault.t.sol";

/// @notice H1 is a conversion hop: custody assertions only, never an LP-bearing behavior.
contract UniswapV4SingleSEBufferHook_ComponentAccounting is FullSpreadRow, HookComponentCustodyBehavior {
    /// @dev Read-only storage inspection, never storage injection into the production proxy.
    function _h1Word(uint256 offset_) internal view returns (uint256) {
        bytes32 slot_ = keccak256(
            abi.encode(uint256(keccak256("indexedex.hooks.uv4.single.se.buffer.hook.storage")) - 1)
        ) & ~bytes32(uint256(0xff));
        return uint256(vm.load(hook, bytes32(uint256(slot_) + offset_)));
    }

    /// @notice Authority is supplied by package initialization, not H1's zero fee oracle.
    function test_HB45_registryProvenanceAndEmptyBooks() public view {
        assertEq(address(uint160(_h1Word(5))), address(indexedexManager));
        assertEq(_h1Word(6), 0, "no attributed pair custody at deployment");
        assertEq(_h1Word(7), 0, "no attributed shares at deployment");
    }

    /// @notice Retained input belongs to H1, but neither it nor ambient funds subsidize another caller.
    function test_HB41_refundBooksExcludeAmbientAndOtherCallers() public {
        fx.fund(hook, 3 ether);
        SeMatrix_FullSpreadV4Fixture(address(fx)).acquireShares(seUT, face, hook, 2 ether);
        uint256 ambientPair_ = _faceOf(hook);
        uint256 ambientShares_ = _seOf(hook);
        _wrapExactIn(10 ether);
        uint256 retained_ = _faceOf(hook) - ambientPair_;
        assertGt(retained_, 0, "actual partial refund");
        assertEq(_h1Word(6), retained_, "only received refund is booked");
        assertEq(_h1Word(7), 0, "ambient shares are not booked");

        fx.fund(rowBob, 5 ether);
        vm.prank(rowBob);
        IERC20(face).approve(address(swapRouter), 5 ether);
        (uint256 quoted_, uint256 refund_) =
            IStandardExchangeIn(seUT).previewExchangeIn(IERC20(face), 5 ether, IERC20(seUT));
        _swapExactInAs(rowBob, true, 5 ether);
        assertEq(_seOf(rowBob), quoted_, "second caller gets only its own output");
        assertEq(_faceOf(rowBob), 0, "second caller pays its entire settled input");
        assertEq(_h1Word(6), retained_ + refund_);
        assertEq(_faceOf(hook), ambientPair_ + retained_ + refund_);
        assertEq(_seOf(hook), ambientShares_);
        assertEq(IERC20(face).allowance(hook, seUT), 0, "no residual pair allowance");
        assertEq(IERC20(seUT).allowance(hook, seUT), 0, "no residual share allowance");

        retained_ = _h1Word(6);
        _unwrapExactIn(1 ether);
        assertEq(_h1Word(6), retained_, "unwrap cannot spend earlier retained pair");
        assertEq(_h1Word(7), 0, "full share consumption leaves zero share book");
        assertEq(_faceOf(hook), ambientPair_ + retained_);
        assertEq(_seOf(hook), ambientShares_);
    }

    /// @notice FullSpread exact-out remains unsupported even with more than enough retained custody.
    function test_HB41_retainedCustodyDoesNotInventExactOutputRoute() public {
        _wrapExactIn(10 ether);
        fx.fund(hook, 100 ether);
        SeMatrix_FullSpreadV4Fixture(address(fx)).acquireShares(seUT, face, hook, 10 ether);
        bytes memory before_ = _hbCustodyState();
        (SwapParams memory wrap_,) = _swapParams(true, int256(1 ether));
        vm.expectRevert(_wrappedHookRevert(abi.encodeWithSelector(IStandardExchangeOut.ExchangeOutNotAvailable.selector)));
        vm.prank(user);
        swapRouter.swapExactOut(poolKey, wrap_, 10 ether, "");
        assertEq(_hbCustodyState(), before_);
        (SwapParams memory unwrap_,) = _swapParams(false, int256(1 ether));
        vm.expectRevert(_wrappedHookRevert(abi.encodeWithSelector(IStandardExchangeOut.ExchangeOutNotAvailable.selector)));
        vm.prank(user);
        swapRouter.swapExactOut(poolKey, unwrap_, 10 ether, "");
        assertEq(_hbCustodyState(), before_);
    }

    /// @notice Real PoolManager final settlement failure rolls back the completed SE receipt and book.
    function test_HB41_outerManagerRollbackRestoresRefundBooks() public {
        _wrapExactIn(10 ether);
        H1UnsettledRouter router_ = new H1UnsettledRouter(pm);
        bytes memory before_ = _hbCustodyState();
        uint256 managerPairs_ = _faceOf(address(pm));
        uint256 managerShares_ = _seOf(address(pm));
        (SwapParams memory params_,) = _swapParams(true, -int256(1 ether));
        vm.expectRevert(IPoolManager.CurrencyNotSettled.selector);
        router_.swapUnsettled(poolKey, params_);
        assertEq(_hbCustodyState(), before_, "outer revert restores attributed custody and SE supply");
        assertEq(_faceOf(address(pm)), managerPairs_);
        assertEq(_seOf(address(pm)), managerShares_);
    }

    /// @notice Removing the registry entry must not silently classify the SE as enabled.
    function test_HB45_unknownRegistryEntryFailsClosed() public {
        address package_ = SeMatrix_FullSpreadV4Fixture(address(fx)).pkg();
        IStandardVault.VaultConfig memory config_ = IStandardVault(seUT).vaultConfig();
        vm.prank(owner);
        IVaultRegistryVaultManager(address(indexedexManager)).unregisterVault(seUT, package_, config_);
        assertEq(IVaultRegistryDisableQuery(address(indexedexManager)).packageOfVault(seUT), address(0));
        bytes memory before_ = _hbCustodyState();
        vm.expectRevert(_wrappedHookRevert(abi.encodeWithSignature("Error(string)", "unregistered SE")));
        this.hbDisabledWrap();
        assertEq(_hbCustodyState(), before_);
        vm.expectRevert(abi.encodeWithSignature("Error(string)", "unregistered SE"));
        hookPkg.processArgs(abi.encode(_defaultPkgArgs()));
    }

    function _hbHook() internal view override returns (address) { return hook; }
    function _hbPairs() internal view override returns (address[] memory pairs_) {
        pairs_ = new address[](1);
        pairs_[0] = face;
    }
    function _hbExchanges() internal view override returns (address[] memory exchanges_) {
        exchanges_ = new address[](1);
        exchanges_[0] = seUT;
    }

    /// @notice An actual mint refund and pre-existing share custody remain on the hook.
    function test_HB41_conversionPreservesAttributedAndAmbientCustody() public {
        SeMatrix_FullSpreadV4Fixture fullSpread_ = SeMatrix_FullSpreadV4Fixture(address(fx));
        fullSpread_.fund(hook, 3 ether);
        fullSpread_.acquireShares(seUT, face, hook, 2 ether);
        uint256 hookPairs_ = _faceOf(hook);
        uint256 hookShares_ = _seOf(hook);
        uint256 userPairs_ = _faceOf(user);
        uint256 userShares_ = _seOf(user);
        uint256 supply_ = IERC20(seUT).totalSupply();
        address feeTo_ = address(IVaultFeeOracleQuery(address(indexedexManager)).feeTo());
        uint256 feeShares_ = IERC20(seUT).balanceOf(feeTo_);
        uint256 fee_ = IVaultFeeOracleQuery(address(indexedexManager)).usageFeeOfVault(seUT);
        if (fee_ > 3e17) fee_ = 3e17;
        uint256 received_ = _wrapExactIn(10 ether);
        assertGt(received_, 0);
        assertEq(userPairs_ - _faceOf(user), 10 ether, "only current input is spent");
        assertEq(_seOf(user) - userShares_, received_);
        uint256 gross_ = IERC20(seUT).totalSupply() - supply_;
        uint256 expectedFee_ = feeTo_ == address(0) ? 0 : gross_ * fee_ / 1e18;
        assertEq(IERC20(seUT).balanceOf(feeTo_) - feeShares_, expectedFee_);
        assertEq(gross_, received_ + expectedFee_, "underlying vault fee is not a Hook LP fee");
        assertGt(_faceOf(hook), hookPairs_, "real refund remains in custody");
        assertEq(_seOf(hook), hookShares_, "ambient shares are not paid out");
        hookPairs_ = _faceOf(hook);
        userPairs_ = _faceOf(user);
        userShares_ = _seOf(user);
        supply_ = IERC20(seUT).totalSupply();
        uint256 paired_ = _unwrapExactIn(received_);
        assertGt(paired_, 0);
        assertEq(_faceOf(user) - userPairs_, paired_);
        assertEq(userShares_ - _seOf(user), received_);
        assertEq(supply_ - IERC20(seUT).totalSupply(), received_);
        assertEq(_faceOf(hook), hookPairs_, "retained refund is not another caller's payout");
        assertEq(_seOf(hook), hookShares_);
    }

    function test_HB45_disabledAddressStillDeliversUnwrap() public { _hbDisabledConversion(false); }
    function test_HB45_disabledPackageStillDeliversUnwrap() public { _hbDisabledConversion(true); }

    function _hbDisabledConversion(bool byPackage_) internal {
        uint256 hookPairs_ = _faceOf(hook);
        uint256 hookShares_ = _seOf(hook);
        address package_ = SeMatrix_FullSpreadV4Fixture(address(fx)).pkg();
        vm.prank(owner);
        if (byPackage_) IVaultRegistryDisableManager(address(indexedexManager)).setPackageDisabled(
            package_, true
        );
        else IVaultRegistryDisableManager(address(indexedexManager)).setVaultAddressDisabled(seUT, true);
        uint256 userPairs_ = _faceOf(user);
        uint256 userShares_ = _seOf(user);
        uint256 supply_ = IERC20(seUT).totalSupply();
        uint256 paired_ = _unwrapExactIn(1 ether);
        assertGt(paired_, 0, "disabled redemption delivers real pair tokens");
        assertEq(_faceOf(user) - userPairs_, paired_);
        assertEq(userShares_ - _seOf(user), 1 ether);
        assertEq(supply_ - IERC20(seUT).totalSupply(), 1 ether);
        assertEq(_faceOf(hook), hookPairs_);
        assertEq(_seOf(hook), hookShares_);
        bytes memory before_ = _hbCustodyState();
        vm.expectRevert(abi.encodeWithSelector(
            CustomRevert.WrappedError.selector, hook, IHooks.beforeSwap.selector,
            abi.encodeWithSelector(IVaultRegistryDisableQuery.VaultDisabled.selector, seUT),
            abi.encodePacked(Hooks.HookCallFailed.selector)
        ));
        this.hbDisabledWrap();
        assertEq(_hbCustodyState(), before_, "failed disabled wrap restores custody and allowances");
        vm.prank(owner);
        if (byPackage_) IVaultRegistryDisableManager(address(indexedexManager)).setPackageDisabled(
            package_, false
        );
        else IVaultRegistryDisableManager(address(indexedexManager)).setVaultAddressDisabled(seUT, false);
        assertGt(_wrapExactIn(1 ether), 0, "re-enabled wrap delivers shares");
    }

    function _hbCustodyState() internal view returns (bytes memory) {
        return abi.encode(_faceOf(hook), _seOf(hook), _faceOf(user), _seOf(user), IERC20(seUT).totalSupply(),
            IERC20(face).allowance(hook, seUT), IERC20(seUT).allowance(hook, seUT),
            IERC20(face).allowance(user, address(swapRouter)), IERC20(seUT).allowance(user, address(swapRouter)),
            _h1Word(5), _h1Word(6), _h1Word(7));
    }

    function hbDisabledWrap() external { _wrapExactIn(1 ether); }
}

/// @notice Test router deliberately leaves its own manager deltas unsettled after a real hook swap.
contract H1UnsettledRouter is IUnlockCallback {
    IPoolManager internal immutable MANAGER;

    constructor(IPoolManager manager_) { MANAGER = manager_; }

    function swapUnsettled(PoolKey memory key_, SwapParams memory params_) external {
        MANAGER.unlock(abi.encode(key_, params_));
    }

    function unlockCallback(bytes calldata data_) external returns (bytes memory) {
        require(msg.sender == address(MANAGER), "not manager");
        (PoolKey memory key_, SwapParams memory params_) = abi.decode(data_, (PoolKey, SwapParams));
        MANAGER.swap(key_, params_, "");
        return "";
    }
}
